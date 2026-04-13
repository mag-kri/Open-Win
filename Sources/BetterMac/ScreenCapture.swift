import Cocoa

/// Screenshot tool. Starts instantly in last used mode.
/// No cycling, no delays. Just works.
/// Region = drag rectangle. Window = click window. Fullscreen = captures screen mouse is on.
final class ScreenCapture {
    static let shared = ScreenCapture()

    enum Mode: Int {
        case region = 0
        case window = 1
        case fullscreen = 2

        var name: String {
            switch self {
            case .region: return "Region"
            case .window: return "Window"
            case .fullscreen: return "Fullscreen"
            }
        }
    }

    private var globalKeyMonitor: Any?
    private static let modeFile = "/tmp/.bettermac_screenshot_mode"

    /// Always reads from file, always writes to file. No in-memory cache.
    var currentMode: Mode {
        get {
            guard let str = try? String(contentsOfFile: ScreenCapture.modeFile, encoding: .utf8),
                  let val = Int(str.trimmingCharacters(in: .whitespacesAndNewlines)),
                  let mode = Mode(rawValue: val) else { return .region }
            return mode
        }
        set {
            try? "\(newValue.rawValue)".write(toFile: ScreenCapture.modeFile, atomically: true, encoding: .utf8)
        }
    }

    func startGlobalMonitor() {
        zlog("[Screenshot] Global monitor installed")
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return }
            zlog("[Screenshot] Global key: \(event.keyCode) mods: \(event.modifierFlags.rawValue)")
            var nsMods: UInt64 = 0
            if event.modifierFlags.contains(.shift) { nsMods |= CGEventFlags.maskShift.rawValue }
            if event.modifierFlags.contains(.option) { nsMods |= CGEventFlags.maskAlternate.rawValue }
            if event.modifierFlags.contains(.control) { nsMods |= CGEventFlags.maskControl.rawValue }
            if event.modifierFlags.contains(.command) { nsMods |= CGEventFlags.maskCommand.rawValue }
            let maskedMods = nsMods & ShortcutBinding.relevantMask

            // ⇧⌥S — take screenshot
            let ssBinding = ShortcutManager.shared.binding(for: .screenshot)
            zlog("[Screenshot] Check: maskedMods=\(maskedMods) bindingMods=\(ssBinding?.modifiers ?? 0) keyCode=\(event.keyCode) bindingKey=\(ssBinding?.keyCode ?? -1)")
            if let binding = ssBinding,
               maskedMods == binding.modifiers && Int64(event.keyCode) == binding.keyCode {
                zlog("[Screenshot] MATCH → capture()")
                self.capture()
            }

            // ⇧⌥Space — cycle mode
            if let binding = ShortcutManager.shared.binding(for: .screenshotCycleMode),
               maskedMods == binding.modifiers && Int64(event.keyCode) == binding.keyCode {
                self.cycleMode()
            }
        }
    }

    /// Take screenshot in current mode instantly
    func capture() {
        // Force save current mode to file (didSet only fires on change)
        try? "\(currentMode.rawValue)".write(toFile: ScreenCapture.modeFile, atomically: true, encoding: .utf8)
        zlog("[Screenshot] capture() mode=\(currentMode.name), saved \(currentMode.rawValue)")
        switch currentMode {
        case .region:
            runScreencapture(args: ["-ic"])
        case .window:
            runScreencapture(args: ["-icW"])
        case .fullscreen:
            captureFullscreen()
        }
    }

    /// Cycle to next mode without capturing (called from shortcut)
    func cycleMode() {
        let prev = currentMode
        let next = (currentMode.rawValue + 1) % 3
        let newMode = Mode(rawValue: next)!
        currentMode = newMode
        zlog("[Screenshot] cycleMode() \(prev.name) → \(newMode.name)")
        ToastWindow.show(message: "Screenshot: \(newMode.name)", icon: "camera")
    }

    private func runScreencapture(args: [String]) {
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            task.arguments = args
            do {
                try task.run()
                task.waitUntilExit()
                DispatchQueue.main.async {
                    if task.terminationStatus == 0 {
                        ToastWindow.show(message: "Copied to clipboard", icon: "doc.on.clipboard")
                    }
                }
            } catch {}
        }
    }

    private func captureFullscreen() {
        let mousePos = NSEvent.mouseLocation
        let screenHeight = NSScreen.screens.map { $0.frame.maxY }.max() ?? 0

        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mousePos) }) else { return }

        let rect = CGRect(
            x: screen.frame.origin.x,
            y: screenHeight - screen.frame.origin.y - screen.frame.height,
            width: screen.frame.width,
            height: screen.frame.height
        )

        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            task.arguments = ["-c", "-R", "\(Int(rect.origin.x)),\(Int(rect.origin.y)),\(Int(rect.width)),\(Int(rect.height))"]
            do {
                try task.run()
                task.waitUntilExit()
                DispatchQueue.main.async {
                    ToastWindow.show(message: "Copied to clipboard", icon: "doc.on.clipboard")
                }
            } catch {}
        }
    }
}
