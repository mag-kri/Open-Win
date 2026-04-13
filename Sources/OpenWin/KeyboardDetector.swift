import Cocoa
import IOKit
import IOKit.hid

/// Detects connected keyboards, auto-creates profiles, and auto-switches
/// profile based on which keyboard is actively being used.
final class KeyboardDetector {
    static let shared = KeyboardDetector()

    struct KeyboardInfo: Equatable {
        let name: String
        let vendorID: Int
        let productID: Int
        let isBuiltIn: Bool
        let transport: String

        var uniqueKey: String { "\(vendorID)_\(productID)" }
    }

    private var manager: IOHIDManager?
    private(set) var keyboards: [KeyboardInfo] = []
    private var deviceMap: [IOHIDDevice: KeyboardInfo] = [:] // track device → info
    private var lastActiveKeyboard: String = ""
    var onKeyboardsChanged: (() -> Void)?

    func start() {
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        guard let manager = manager else { return }

        let matching: [String: Any] = [
            kIOHIDDeviceUsagePageKey as String: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey as String: kHIDUsage_GD_Keyboard,
        ]
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)

        let ctx = Unmanaged.passUnretained(self).toOpaque()

        IOHIDManagerRegisterDeviceMatchingCallback(manager, { ctx, result, sender, device in
            let detector = Unmanaged<KeyboardDetector>.fromOpaque(ctx!).takeUnretainedValue()
            detector.deviceConnected(device)
        }, ctx)

        IOHIDManagerRegisterDeviceRemovalCallback(manager, { ctx, result, sender, device in
            let detector = Unmanaged<KeyboardDetector>.fromOpaque(ctx!).takeUnretainedValue()
            detector.deviceDisconnected(device)
        }, ctx)

        // Register for input from ALL keyboards to detect which one is active
        IOHIDManagerRegisterInputValueCallback(manager, { ctx, result, sender, value in
            let detector = Unmanaged<KeyboardDetector>.fromOpaque(ctx!).takeUnretainedValue()
            let device = IOHIDValueGetElement(value)
            let hidDevice = IOHIDElementGetDevice(device)
            detector.inputFromDevice(hidDevice)
        }, ctx)

        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))

        zlog("[Keyboard] Detector started")
    }

    func stop() {
        if let manager = manager {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        manager = nil
    }

    // MARK: - Device connect/disconnect

    private func deviceConnected(_ device: IOHIDDevice) {
        guard let info = extractInfo(device) else { return }
        deviceMap[device] = info
        if !keyboards.contains(where: { $0.uniqueKey == info.uniqueKey }) {
            keyboards.append(info)
            zlog("[Keyboard] Connected: \(info.name) (\(info.transport), \(info.isBuiltIn ? "built-in" : "external"))")
            autoCreateProfile(for: info)
            DispatchQueue.main.async { self.onKeyboardsChanged?() }
        }
    }

    private func deviceDisconnected(_ device: IOHIDDevice) {
        if let info = deviceMap[device] {
            keyboards.removeAll { $0.uniqueKey == info.uniqueKey }
            zlog("[Keyboard] Disconnected: \(info.name)")
            DispatchQueue.main.async { self.onKeyboardsChanged?() }
        }
        deviceMap.removeValue(forKey: device)
    }

    // MARK: - Auto-switch profile on input

    private func inputFromDevice(_ device: IOHIDDevice) {
        guard let info = deviceMap[device] else { return }

        // Only switch if a different keyboard is now active
        guard info.name != lastActiveKeyboard else { return }
        lastActiveKeyboard = info.name

        // Find matching profile and switch to it
        let sm = ShortcutManager.shared
        if let profile = sm.profiles.first(where: { $0.name == info.name }),
           profile.id != sm.activeProfileId {
            DispatchQueue.main.async {
                sm.switchProfile(profile.id)
                zlog("[Keyboard] Auto-switched to profile: \(info.name)")
                ToastWindow.show(message: "Keyboard: \(info.name)", icon: "keyboard")
            }
        }
    }

    // MARK: - Extract device info

    private func extractInfo(_ device: IOHIDDevice) -> KeyboardInfo? {
        let name = propString(device, kIOHIDProductKey) ?? "Unknown Keyboard"
        let vendorID = propInt(device, kIOHIDVendorIDKey) ?? 0
        let productID = propInt(device, kIOHIDProductIDKey) ?? 0
        let builtIn = propInt(device, kIOHIDBuiltInKey) ?? 0
        let transport = propString(device, kIOHIDTransportKey) ?? "Unknown"

        if name.lowercased().contains("trackpad") || name.lowercased().contains("mouse") {
            return nil
        }

        return KeyboardInfo(
            name: name,
            vendorID: vendorID,
            productID: productID,
            isBuiltIn: builtIn == 1,
            transport: transport
        )
    }

    private func autoCreateProfile(for kb: KeyboardInfo) {
        let sm = ShortcutManager.shared
        if sm.profiles.contains(where: { $0.name == kb.name }) { return }
        let _ = sm.createProfile(name: kb.name, copyFrom: sm.activeProfileId)
        zlog("[Keyboard] Auto-created profile: \(kb.name)")
        ToastWindow.show(message: "New keyboard: \(kb.name)", icon: "keyboard")
    }

    // MARK: - Property helpers

    private func propString(_ device: IOHIDDevice, _ key: String) -> String? {
        IOHIDDeviceGetProperty(device, key as CFString) as? String
    }

    private func propInt(_ device: IOHIDDevice, _ key: String) -> Int? {
        IOHIDDeviceGetProperty(device, key as CFString) as? Int
    }
}
