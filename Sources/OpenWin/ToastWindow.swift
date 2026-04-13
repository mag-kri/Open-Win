import Cocoa

final class ToastWindow: NSWindow {
    private static var current: ToastWindow?
    private var hideTimer: Timer?

    static func show(message: String, icon: String = "rectangle.split.2x2") {
        // Don't show if user disabled toasts
        if UserDefaults.standard.object(forKey: "showToasts") != nil && !UserDefaults.standard.bool(forKey: "showToasts") {
            return
        }

        DispatchQueue.main.async {
            current?.orderOut(nil)
            let toast = ToastWindow(message: message, icon: icon)
            current = toast
            toast.showToast()
        }
    }

    private init(message: String, icon: String) {
        let width: CGFloat = 280
        let height: CGFloat = 52

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

        self.level = .floating
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .stationary]

        setupContent(message: message, icon: icon)
    }

    private func setupContent(message: String, icon: String) {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 280, height: 52))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.95).cgColor
        container.layer?.cornerRadius = 12
        container.layer?.borderWidth = 0.5
        container.layer?.borderColor = NSColor.separatorColor.cgColor

        // Shadow
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.2)
        shadow.shadowBlurRadius = 12
        shadow.shadowOffset = NSSize(width: 0, height: -2)
        container.shadow = shadow

        // Icon
        let iconView = NSImageView(frame: NSRect(x: 16, y: 12, width: 28, height: 28))
        if let img = NSImage(systemSymbolName: icon, accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .medium)
            iconView.image = img.withSymbolConfiguration(config)
            iconView.contentTintColor = .systemBlue
        }
        container.addSubview(iconView)

        // Message
        let label = NSTextField(frame: NSRect(x: 52, y: 14, width: 210, height: 24))
        label.stringValue = message
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .labelColor
        label.isBezeled = false
        label.isEditable = false
        label.drawsBackground = false
        label.isSelectable = false
        container.addSubview(label)

        self.contentView = container
    }

    func showToast() {
        self.alphaValue = 0
        makeKeyAndOrderFront(nil)

        // Fade in
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = 1.0
        }

        // Auto-hide after 1.5 seconds
        hideTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
            self?.fadeOut()
        }
    }

    private func fadeOut() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.4
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.orderOut(nil)
            if ToastWindow.current === self {
                ToastWindow.current = nil
            }
        })
    }
}
