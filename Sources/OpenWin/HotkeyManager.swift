import Cocoa
import Carbon

final class HotkeyManager {
    static let shared = HotkeyManager()

    private var keyTap: CFMachPort?
    private var keyRunLoopSource: CFRunLoopSource?

    var onToggleOverlay: (() -> Void)?
    var onZoneEditor: (() -> Void)?
    var onScreenCapture: (() -> Void)?
    var onAltTab: (() -> Void)?
    var onAltTabCycle: (() -> Void)?
    var altTabActive = false

    /// When true, pass ALL keys through (for KeyRecorderView)
    var paused = false

    func start() {
        // Only create tap once — never destroy it
        guard keyTap == nil else {
            // Re-enable if it was disabled
            if let tap = keyTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }

        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon!).takeUnretainedValue()

                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let tap = manager.keyTap {
                        CGEvent.tapEnable(tap: tap, enable: true)
                    }
                    return Unmanaged.passRetained(event)
                }

                guard type == .keyDown else { return Unmanaged.passRetained(event) }

                // When paused, pass everything through (for shortcut recording)
                if manager.paused { return Unmanaged.passRetained(event) }

                if manager.handleKeyEvent(event) {
                    return nil
                }
                return Unmanaged.passRetained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            zlog("[Hotkey] FAILED to create key tap!")
            return
        }

        keyTap = tap
        keyRunLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), keyRunLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        zlog("[Hotkey] Key tap started")
    }

    func stop() {
        // Don't destroy the tap — just pause it
        paused = true
    }

    func resume() {
        paused = false
        // Re-enable in case macOS disabled it
        if let tap = keyTap { CGEvent.tapEnable(tap: tap, enable: true) }
    }

    private func handleKeyEvent(_ event: CGEvent) -> Bool {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        guard let action = ShortcutManager.shared.action(forKeyCode: keyCode, flags: flags) else {
            return false
        }

        let wm = WindowManager.shared

        switch action {
        case .altTab:
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if self.altTabActive { self.onAltTabCycle?() }
                else { self.onAltTab?() }
            }
            return true
        case .screenshot:
            DispatchQueue.main.async { [weak self] in self?.onScreenCapture?() }
            return true
        case .screenshotCycleMode:
            DispatchQueue.main.async { ScreenCapture.shared.cycleMode() }
            return true
        case .snapLeft: wm.moveLeft(); return true
        case .snapRight: wm.moveRight(); return true
        case .snapTop: wm.moveTop(); return true
        case .snapBottom: wm.moveBottom(); return true
        case .snapTopLeft: wm.moveTopLeft(); return true
        case .snapTopRight: wm.moveTopRight(); return true
        case .snapBottomLeft: wm.moveBottomLeft(); return true
        case .snapBottomRight: wm.moveBottomRight(); return true
        case .center: wm.moveCenter(); return true
        case .maximize: wm.maximize(); return true
        case .zoneEditor:
            DispatchQueue.main.async { [weak self] in self?.onZoneEditor?() }
            return true
        case .toggleOverlay:
            DispatchQueue.main.async { [weak self] in self?.onToggleOverlay?() }
            return true
        case .dragModifier:
            return false
        }
    }
}
