import Cocoa

final class WelcomeWindow: NSWindow {
    private var onStart: (() -> Void)?

    init(onStart: @escaping () -> Void) {
        self.onStart = onStart

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 580),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        self.title = "Velkommen til OpenWin"
        self.isReleasedWhenClosed = false
        self.center()
        self.isMovableByWindowBackground = true

        setupContent()
    }

    private func setupContent() {
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 520, height: 580))
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        // App icon
        let iconView = NSImageView(frame: NSRect(x: 195, y: 470, width: 64, height: 64))
        if let img = NSImage(systemSymbolName: "rectangle.split.2x2.fill", accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 48, weight: .medium)
            iconView.image = img.withSymbolConfiguration(config)
            iconView.contentTintColor = .systemBlue
        }
        contentView.addSubview(iconView)

        // Title
        let titleLabel = makeLabel(
            text: "OpenWin",
            frame: NSRect(x: 0, y: 430, width: 520, height: 36),
            fontSize: 28, weight: .bold, alignment: .center
        )
        contentView.addSubview(titleLabel)

        // Subtitle
        let subtitleLabel = makeLabel(
            text: "Vindusbehandling for macOS — inspirert av PowerToys FancyZones",
            frame: NSRect(x: 40, y: 400, width: 440, height: 24),
            fontSize: 13, weight: .regular, alignment: .center, color: .secondaryLabelColor
        )
        contentView.addSubview(subtitleLabel)

        // Divider
        let divider = NSBox(frame: NSRect(x: 40, y: 390, width: 440, height: 1))
        divider.boxType = .separator
        contentView.addSubview(divider)

        // Shortcuts section
        let shortcutsTitle = makeLabel(
            text: "Tastatursnarveger",
            frame: NSRect(x: 40, y: 350, width: 440, height: 24),
            fontSize: 15, weight: .semibold, alignment: .left
        )
        contentView.addSubview(shortcutsTitle)

        let shortcuts: [(String, String)] = [
            ("⌃⌥Z", "Vis/skjul zone-overlay"),
            ("⌃⌥← →", "Venstre / høyre halvdel"),
            ("⌃⌥↑ ↓", "Øvre / nedre halvdel"),
            ("⌃⌥U I J K", "Kvartdeler (hjørner)"),
            ("⌃⌥C", "Sentrer vindu"),
            ("⌃⌥↵", "Maksimer vindu"),
        ]

        for (i, shortcut) in shortcuts.enumerated() {
            let y = 315 - (i * 32)
            let keyBg = ShortcutKeyView(
                frame: NSRect(x: 50, y: y, width: 110, height: 26),
                text: shortcut.0
            )
            contentView.addSubview(keyBg)

            let descLabel = makeLabel(
                text: shortcut.1,
                frame: NSRect(x: 175, y: y, width: 300, height: 26),
                fontSize: 13, weight: .regular, alignment: .left
            )
            contentView.addSubview(descLabel)
        }

        // Zone overlay info
        let overlayInfo = makeLabel(
            text: "Trykk ⌃⌥Z for å vise soner, klikk eller trykk 1-9 for å plassere vindu.",
            frame: NSRect(x: 50, y: 105, width: 420, height: 36),
            fontSize: 12, weight: .regular, alignment: .center, color: .secondaryLabelColor
        )
        contentView.addSubview(overlayInfo)

        // Accessibility button
        let accessBtn = NSButton(frame: NSRect(x: 110, y: 58, width: 300, height: 32))
        accessBtn.title = "  Åpne Tilgjengelighetsinnstillinger"
        accessBtn.bezelStyle = .rounded
        accessBtn.target = self
        accessBtn.action = #selector(openAccessibility)
        if let img = NSImage(systemSymbolName: "lock.shield", accessibilityDescription: nil) {
            accessBtn.image = img
            accessBtn.imagePosition = .imageLeading
        }
        contentView.addSubview(accessBtn)

        // Start button
        let startBtn = NSButton(frame: NSRect(x: 160, y: 14, width: 200, height: 38))
        startBtn.title = "Start OpenWin"
        startBtn.bezelStyle = .rounded
        startBtn.contentTintColor = .white
        startBtn.wantsLayer = true
        startBtn.layer?.backgroundColor = NSColor.systemBlue.cgColor
        startBtn.layer?.cornerRadius = 8
        startBtn.isBordered = false
        startBtn.font = .systemFont(ofSize: 14, weight: .semibold)
        startBtn.target = self
        startBtn.action = #selector(startApp)
        contentView.addSubview(startBtn)

        self.contentView = contentView
    }

    @objc private func openAccessibility() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    @objc private func startApp() {
        UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
        close()
        onStart?()
    }

    private func makeLabel(text: String, frame: NSRect, fontSize: CGFloat, weight: NSFont.Weight, alignment: NSTextAlignment, color: NSColor = .labelColor) -> NSTextField {
        let label = NSTextField(frame: frame)
        label.stringValue = text
        label.font = .systemFont(ofSize: fontSize, weight: weight)
        label.textColor = color
        label.alignment = alignment
        label.isBezeled = false
        label.isEditable = false
        label.drawsBackground = false
        label.isSelectable = false
        return label
    }
}

// MARK: - Shortcut key badge view

final class ShortcutKeyView: NSView {
    private let text: String

    init(frame: CGRect, text: String) {
        self.text = text
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 5, yRadius: 5)
        NSColor.controlBackgroundColor.setFill()
        path.fill()
        NSColor.separatorColor.setStroke()
        path.lineWidth = 1
        path.stroke()

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.labelColor,
        ]
        let size = text.size(withAttributes: attrs)
        let point = CGPoint(
            x: (bounds.width - size.width) / 2,
            y: (bounds.height - size.height) / 2
        )
        text.draw(at: point, withAttributes: attrs)
    }
}
