import Cocoa
import ServiceManagement

final class PreferencesWindow: NSWindow {

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        self.title = "OpenWin Innstillinger"
        self.isReleasedWhenClosed = false
        self.center()

        setupContent()
    }

    private func setupContent() {
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 500))

        // Header
        let header = makeLabel(
            text: "Innstillinger",
            frame: NSRect(x: 30, y: 450, width: 420, height: 32),
            fontSize: 22, weight: .bold
        )
        contentView.addSubview(header)

        // --- General section ---
        let generalTitle = makeSectionTitle("Generelt", y: 410)
        contentView.addSubview(generalTitle)

        let loginToggle = NSButton(checkboxWithTitle: "  Start OpenWin ved innlogging", target: self, action: #selector(toggleLoginItem))
        loginToggle.frame = NSRect(x: 40, y: 378, width: 300, height: 22)
        loginToggle.state = UserDefaults.standard.bool(forKey: "startAtLogin") ? .on : .off
        contentView.addSubview(loginToggle)

        let toastToggle = NSButton(checkboxWithTitle: "  Vis toast-varsler ved vindusflytting", target: self, action: #selector(toggleToast))
        toastToggle.frame = NSRect(x: 40, y: 350, width: 300, height: 22)
        toastToggle.state = UserDefaults.standard.bool(forKey: "showToasts") != false ? .on : .off
        contentView.addSubview(toastToggle)

        // --- Divider ---
        let div1 = NSBox(frame: NSRect(x: 30, y: 338, width: 420, height: 1))
        div1.boxType = .separator
        contentView.addSubview(div1)

        // --- Layout section ---
        let layoutTitle = makeSectionTitle("Layout", y: 308)
        contentView.addSubview(layoutTitle)

        let layouts = ["Standard (9 soner)", "Halvdeler (2 soner)", "Tredjedeler (3 soner)", "Widescreen (5 soner)"]
        let popup = NSPopUpButton(frame: NSRect(x: 40, y: 274, width: 250, height: 28))
        popup.addItems(withTitles: layouts)
        let saved = UserDefaults.standard.integer(forKey: "selectedLayout")
        popup.selectItem(at: saved)
        popup.target = self
        popup.action = #selector(layoutChanged(_:))
        contentView.addSubview(popup)

        // --- Divider ---
        let div2 = NSBox(frame: NSRect(x: 30, y: 258, width: 420, height: 1))
        div2.boxType = .separator
        contentView.addSubview(div2)

        // --- Shortcuts section ---
        let shortcutsTitle = makeSectionTitle("Snarveger", y: 228)
        contentView.addSubview(shortcutsTitle)

        let shortcuts: [(String, String)] = [
            ("⌃⌥Z", "Vis/skjul soner"),
            ("⌃⌥←", "Venstre halvdel"),
            ("⌃⌥→", "Høyre halvdel"),
            ("⌃⌥↑", "Øvre halvdel"),
            ("⌃⌥↓", "Nedre halvdel"),
            ("⌃⌥U / I", "Øvre venstre / høyre"),
            ("⌃⌥J / K", "Nedre venstre / høyre"),
            ("⌃⌥C", "Sentrer"),
            ("⌃⌥↵", "Maksimer"),
        ]

        for (i, shortcut) in shortcuts.enumerated() {
            let y = 196 - (i * 22)
            let keyLabel = makeLabel(
                text: shortcut.0,
                frame: NSRect(x: 50, y: y, width: 100, height: 20),
                fontSize: 12, weight: .medium, color: .systemBlue
            )
            keyLabel.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
            contentView.addSubview(keyLabel)

            let descLabel = makeLabel(
                text: shortcut.1,
                frame: NSRect(x: 160, y: y, width: 280, height: 20),
                fontSize: 12, weight: .regular, color: .secondaryLabelColor
            )
            contentView.addSubview(descLabel)
        }

        // Version
        let version = makeLabel(
            text: "OpenWin v1.0 — Bygget med Swift",
            frame: NSRect(x: 0, y: 8, width: 480, height: 18),
            fontSize: 11, weight: .regular, color: .tertiaryLabelColor
        )
        version.alignment = .center
        contentView.addSubview(version)

        self.contentView = contentView
    }

    @objc private func toggleLoginItem(_ sender: NSButton) {
        let enabled = sender.state == .on
        UserDefaults.standard.set(enabled, forKey: "startAtLogin")
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Login item error: \(error)")
            }
        }
    }

    @objc private func toggleToast(_ sender: NSButton) {
        UserDefaults.standard.set(sender.state == .on, forKey: "showToasts")
    }

    @objc private func layoutChanged(_ sender: NSPopUpButton) {
        UserDefaults.standard.set(sender.indexOfSelectedItem, forKey: "selectedLayout")
        NotificationCenter.default.post(name: .layoutChanged, object: nil)
    }

    private func makeSectionTitle(_ text: String, y: CGFloat) -> NSTextField {
        return makeLabel(text: text, frame: NSRect(x: 30, y: y, width: 420, height: 22), fontSize: 14, weight: .semibold)
    }

    private func makeLabel(text: String, frame: NSRect, fontSize: CGFloat, weight: NSFont.Weight, color: NSColor = .labelColor) -> NSTextField {
        let label = NSTextField(frame: frame)
        label.stringValue = text
        label.font = .systemFont(ofSize: fontSize, weight: weight)
        label.textColor = color
        label.isBezeled = false
        label.isEditable = false
        label.drawsBackground = false
        label.isSelectable = false
        return label
    }
}

extension Notification.Name {
    static let layoutChanged = Notification.Name("layoutChanged")
}
