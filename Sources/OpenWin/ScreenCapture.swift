import Cocoa

/// Snip & Sketch-style screenshot. Press ⇧⌥S to start in region mode.
/// Press Space to cycle between modes. Click/Enter to capture. Escape to cancel.
final class ScreenCapture {
    static let shared = ScreenCapture()

    enum Mode: Int, CaseIterable {
        case region = 0
        case window = 1
        case fullscreen = 2

        var name: String {
            switch self {
            case .region: return "Område"
            case .window: return "Vindu"
            case .fullscreen: return "Fullskjerm"
            }
        }

        var icon: String {
            switch self {
            case .region: return "rectangle.dashed"
            case .window: return "macwindow"
            case .fullscreen: return "rectangle.fill"
            }
        }
    }

    private var modeWindow: CaptureModeOverlay?

    func start() {
        captureWithMode(.region)
    }

    func captureWithMode(_ mode: Mode) {
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")

            switch mode {
            case .region:
                task.arguments = ["-ic"]
            case .window:
                task.arguments = ["-icW"]
            case .fullscreen:
                task.arguments = ["-c"]
            }

            do {
                try task.run()
                task.waitUntilExit()
                DispatchQueue.main.async {
                    ToastWindow.show(message: "Kopiert til utklippstavle", icon: "doc.on.clipboard")
                }
            } catch {
                zlog("[Screenshot] Error: \(error)")
            }
        }
    }
}

// MARK: - Mode overlay + capture

final class CaptureModeOverlay: NSWindow {
    private var currentMode: ScreenCapture.Mode = .region
    private var modeLabel: NSTextField!
    private var iconView: NSImageView!
    private var keyMonitor: Any?
    private var globalKeyMonitor: Any?

    init() {
        let width: CGFloat = 200
        let height: CGFloat = 80

        guard let screen = NSScreen.main else {
            super.init(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
            return
        }

        let x = screen.frame.midX - width / 2
        let y = screen.visibleFrame.maxY - height - 20

        super.init(
            contentRect: NSRect(x: x, y: y, width: width, height: height),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        self.level = .screenSaver
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.collectionBehavior = [.canJoinAllSpaces, .stationary]

        setupContent()
    }

    private func setupContent() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 80))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.95).cgColor
        container.layer?.cornerRadius = 14
        container.layer?.borderWidth = 0.5
        container.layer?.borderColor = NSColor.separatorColor.cgColor

        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
        shadow.shadowBlurRadius = 16
        shadow.shadowOffset = NSSize(width: 0, height: -3)
        container.shadow = shadow

        // Icon
        iconView = NSImageView(frame: NSRect(x: (200 - 28) / 2, y: 38, width: 28, height: 28))
        iconView.contentTintColor = .systemBlue
        container.addSubview(iconView)

        // Mode name
        modeLabel = NSTextField(frame: NSRect(x: 0, y: 18, width: 200, height: 20))
        modeLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        modeLabel.textColor = .labelColor
        modeLabel.alignment = .center
        modeLabel.isBezeled = false
        modeLabel.isEditable = false
        modeLabel.drawsBackground = false
        container.addSubview(modeLabel)

        // Hint
        let hint = NSTextField(frame: NSRect(x: 0, y: 3, width: 200, height: 14))
        hint.stringValue = "Space: bytt · Enter: ta bilde"
        hint.font = .systemFont(ofSize: 9, weight: .medium)
        hint.textColor = .tertiaryLabelColor
        hint.alignment = .center
        hint.isBezeled = false
        hint.isEditable = false
        hint.drawsBackground = false
        container.addSubview(hint)

        self.contentView = container
        updateModeDisplay()
    }

    private func updateModeDisplay() {
        modeLabel.stringValue = currentMode.name
        if let img = NSImage(systemSymbolName: currentMode.icon, accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 20, weight: .medium)
            iconView.image = img.withSymbolConfiguration(config)
        }
    }

    func show() {
        self.alphaValue = 0
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            self.animator().alphaValue = 1
        }

        let handleKey: (NSEvent) -> Void = { [weak self] event in
            guard let self = self else { return }
            zlog("[Screenshot] Key: \(event.keyCode)")
            switch event.keyCode {
            case 49: // Space
                let next = (self.currentMode.rawValue + 1) % ScreenCapture.Mode.allCases.count
                self.currentMode = ScreenCapture.Mode(rawValue: next)!
                self.updateModeDisplay()
            case 36: // Enter
                zlog("[Screenshot] Capturing: \(self.currentMode.name)")
                self.capture()
            case 53: // Escape
                self.dismiss()
            default: break
            }
        }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handleKey(event)
            return event
        }
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            handleKey(event)
        }
    }

    func dismiss() {
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
        if let m = globalKeyMonitor { NSEvent.removeMonitor(m); globalKeyMonitor = nil }
        self.orderOut(nil)
    }

    override var canBecomeKey: Bool { true }

    private func capture() {
        let mode = currentMode
        dismiss()

        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.2) {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")

            switch mode {
            case .region:
                task.arguments = ["-ic"]
            case .window:
                task.arguments = ["-icW"]
            case .fullscreen:
                task.arguments = ["-c"]
            }

            do {
                try task.run()
                task.waitUntilExit()
                DispatchQueue.main.async {
                    ToastWindow.show(message: "Kopiert til utklippstavle", icon: "doc.on.clipboard")
                }
            } catch {
                zlog("[Screenshot] Error: \(error)")
            }
        }
    }
}
