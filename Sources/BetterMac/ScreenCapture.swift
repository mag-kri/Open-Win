import Cocoa

/// Screenshot tool. Starts instantly in last used mode.
/// No cycling, no delays. Just works.
/// Region = drag rectangle. Window = click window. Fullscreen = captures screen mouse is on.
final class ScreenCapture {
    static let shared = ScreenCapture()
    private static let modeDefaultsKey = "screenshotMode"
    private static let legacyModeFile = "/tmp/.bettermac_screenshot_mode"

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

        var interactiveArgs: [String] {
            switch self {
            case .region:
                return ["-ic"]
            case .window:
                return ["-icW"]
            case .fullscreen:
                return ["-ic"]
            }
        }
    }

    private var globalKeyMonitor: Any?
    private(set) var interactiveCaptureActive = false

    /// Persist the last selected screenshot mode so it survives app relaunches.
    var currentMode: Mode {
        get {
            if let stored = UserDefaults.standard.object(forKey: ScreenCapture.modeDefaultsKey) as? Int,
               let mode = Mode(rawValue: stored) {
                return mode
            }

            if let str = try? String(contentsOfFile: ScreenCapture.legacyModeFile, encoding: .utf8),
               let val = Int(str.trimmingCharacters(in: .whitespacesAndNewlines)),
               let mode = Mode(rawValue: val) {
                UserDefaults.standard.set(mode.rawValue, forKey: ScreenCapture.modeDefaultsKey)
                return mode
            }

            let rawValue = UserDefaults.standard.object(forKey: ScreenCapture.modeDefaultsKey) as? Int ?? Mode.region.rawValue
            return Mode(rawValue: rawValue) ?? .region
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: ScreenCapture.modeDefaultsKey)
        }
    }

    func startGlobalMonitor() {
        zlog("[Screenshot] Global monitor installed")
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return }
            self.observeKeyEvent(
                keyCode: Int64(event.keyCode),
                flags: CGEventFlags(rawValue: UInt64(event.modifierFlags.rawValue)),
                source: "global"
            )
        }
    }

    /// Take screenshot in current mode instantly
    func capture() {
        let mode = currentMode
        zlog("[Screenshot] capture() mode=\(mode.name)")
        switch mode {
        case .region:
            runInteractiveCapture(startingIn: mode)
        case .window:
            runInteractiveCapture(startingIn: mode)
        case .fullscreen:
            captureFullscreen()
        }
    }

    /// Cycle to next mode and show toast
    func cycleMode() {
        let next = (currentMode.rawValue + 1) % 3
        let newMode = Mode(rawValue: next)!
        currentMode = newMode
        zlog("[Screenshot] cycleMode() → \(newMode.name)")
        ToastWindow.show(message: "Screenshot: \(newMode.name)", icon: "camera")
    }

    private func runInteractiveCapture(startingIn mode: Mode) {
        currentMode = mode
        interactiveCaptureActive = true
        zlog("[Screenshot] interactive capture started in \(mode.name)")
        runScreencapture(args: mode.interactiveArgs)
    }

    func observeKeyEvent(keyCode: Int64, flags: CGEventFlags, source: String) {
        guard interactiveCaptureActive else { return }

        let maskedMods = flags.rawValue & ShortcutBinding.relevantMask
        guard keyCode == 49, maskedMods == 0 else { return }

        toggleInteractiveMode(source: source)
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
                    self.interactiveCaptureActive = false
                    zlog("[Screenshot] interactive capture ended status=\(task.terminationStatus) remembered=\(self.currentMode.name)")
                    if task.terminationStatus == 0 {
                        ToastWindow.show(message: "Copied to clipboard", icon: "doc.on.clipboard")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.interactiveCaptureActive = false
                    zlog("[Screenshot] interactive capture failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func toggleInteractiveMode(source: String) {
        let newMode: Mode
        switch currentMode {
        case .region:
            newMode = .window
        case .window:
            newMode = .region
        case .fullscreen:
            newMode = .region
        }

        currentMode = newMode
        zlog("[Screenshot] interactive toggle (\(source)) → \(newMode.name)")
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
