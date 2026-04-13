import Cocoa
import ServiceManagement

final class PreferencesWindow: NSWindow {

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 680),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        self.title = "BetterMac Preferences"
        self.isReleasedWhenClosed = false
        self.center()

        setupContent()
    }

    private func setupContent() {
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 680))

        // Header
        let header = makeLabel(text: "Preferences", frame: NSRect(x: 30, y: 635, width: 420, height: 32), fontSize: 22, weight: .bold)
        contentView.addSubview(header)

        // --- General ---
        let generalTitle = makeSectionTitle("General", y: 600)
        contentView.addSubview(generalTitle)

        let loginToggle = NSButton(checkboxWithTitle: "  Start BetterMac at login", target: self, action: #selector(toggleLoginItem))
        loginToggle.frame = NSRect(x: 40, y: 573, width: 300, height: 22)
        loginToggle.state = UserDefaults.standard.bool(forKey: "startAtLogin") ? .on : .off
        contentView.addSubview(loginToggle)

        let toastToggle = NSButton(checkboxWithTitle: "  Show toast notifications", target: self, action: #selector(toggleToast))
        toastToggle.frame = NSRect(x: 40, y: 547, width: 300, height: 22)
        toastToggle.state = UserDefaults.standard.bool(forKey: "showToasts") != false ? .on : .off
        contentView.addSubview(toastToggle)

        let focusToggle = NSButton(checkboxWithTitle: "  Windows-style Focus (click-through)", target: self, action: #selector(toggleWindowsFocus))
        focusToggle.frame = NSRect(x: 40, y: 521, width: 300, height: 22)
        focusToggle.state = ClickThrough.shared.isEnabled ? .on : .off
        contentView.addSubview(focusToggle)


        // --- Divider ---
        let div1 = NSBox(frame: NSRect(x: 30, y: 508, width: 420, height: 1))
        div1.boxType = .separator
        contentView.addSubview(div1)

        // --- Keyboard Shortcuts (embedded view) ---
        let shortcutsTitle = makeSectionTitle("Keyboard Shortcuts", y: 482)
        contentView.addSubview(shortcutsTitle)

        let shortcutsView = ShortcutPreferencesView(frame: NSRect(x: 40, y: 42, width: 400, height: 435))
        contentView.addSubview(shortcutsView)

        // --- Divider ---
        let div2 = NSBox(frame: NSRect(x: 30, y: 34, width: 420, height: 1))
        div2.boxType = .separator
        contentView.addSubview(div2)

        // Version
        let version = makeLabel(
            text: "BetterMac v1.2 — Built with Swift",
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
                if enabled { try SMAppService.mainApp.register() }
                else { try SMAppService.mainApp.unregister() }
            } catch { }
        }
    }

    @objc private func toggleToast(_ sender: NSButton) {
        UserDefaults.standard.set(sender.state == .on, forKey: "showToasts")
    }

    @objc private func toggleWindowsFocus(_ sender: NSButton) {
        ClickThrough.shared.isEnabled = sender.state == .on
    }


    private func makeSectionTitle(_ text: String, y: CGFloat) -> NSTextField {
        return makeLabel(text: text, frame: NSRect(x: 30, y: y, width: 420, height: 22), fontSize: 14, weight: .semibold)
    }

    private func makeLabel(text: String, frame: NSRect, fontSize: CGFloat, weight: NSFont.Weight, color: NSColor = .labelColor) -> NSTextField {
        let l = NSTextField(frame: frame)
        l.stringValue = text; l.font = .systemFont(ofSize: fontSize, weight: weight)
        l.textColor = color; l.isBezeled = false; l.isEditable = false; l.drawsBackground = false; l.isSelectable = false
        return l
    }
}

extension Notification.Name {
    static let layoutChanged = Notification.Name("layoutChanged")
}
