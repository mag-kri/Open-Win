import Cocoa
import ServiceManagement

final class PreferencesWindow: NSWindow {

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 820),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        self.title = "BetterMac Preferences"
        self.isReleasedWhenClosed = false
        self.center()

        setupContent()
    }

    private var speedSlider: NSSlider?
    private var speedLabel: NSTextField?
    private var speedRow: NSView?

    private func setupContent() {
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 820))

        // Header
        let header = makeLabel(text: "Preferences", frame: NSRect(x: 30, y: 775, width: 420, height: 32), fontSize: 22, weight: .bold)
        contentView.addSubview(header)

        // --- General ---
        let generalTitle = makeSectionTitle("General", y: 740)
        contentView.addSubview(generalTitle)

        let loginToggle = NSButton(checkboxWithTitle: "  Start BetterMac at login", target: self, action: #selector(toggleLoginItem))
        loginToggle.frame = NSRect(x: 40, y: 713, width: 300, height: 22)
        loginToggle.state = UserDefaults.standard.bool(forKey: "startAtLogin") ? .on : .off
        contentView.addSubview(loginToggle)

        let toastToggle = NSButton(checkboxWithTitle: "  Show toast notifications", target: self, action: #selector(toggleToast))
        toastToggle.frame = NSRect(x: 40, y: 687, width: 300, height: 22)
        toastToggle.state = UserDefaults.standard.bool(forKey: "showToasts") != false ? .on : .off
        contentView.addSubview(toastToggle)

        let focusToggle = NSButton(checkboxWithTitle: "  Windows-style Focus (click-through)", target: self, action: #selector(toggleWindowsFocus))
        focusToggle.frame = NSRect(x: 40, y: 661, width: 300, height: 22)
        focusToggle.state = ClickThrough.shared.isEnabled ? .on : .off
        contentView.addSubview(focusToggle)

        // --- Divider ---
        let div0 = NSBox(frame: NSRect(x: 30, y: 648, width: 420, height: 1))
        div0.boxType = .separator
        contentView.addSubview(div0)

        // --- Mouse & Scroll ---
        let mouseTitle = makeSectionTitle("Mouse & Scroll", y: 622)
        contentView.addSubview(mouseTitle)

        let scrollToggle = NSButton(checkboxWithTitle: "  Windows-style scroll direction (reverse)", target: self, action: #selector(toggleWindowsScroll))
        scrollToggle.frame = NSRect(x: 40, y: 595, width: 360, height: 22)
        scrollToggle.state = WindowsMouse.shared.scrollEnabled ? .on : .off
        contentView.addSubview(scrollToggle)

        let accelToggle = NSButton(checkboxWithTitle: "  Windows-style mouse acceleration (linear)", target: self, action: #selector(toggleWindowsAccel))
        accelToggle.frame = NSRect(x: 40, y: 569, width: 360, height: 22)
        accelToggle.state = WindowsMouse.shared.accelEnabled ? .on : .off
        contentView.addSubview(accelToggle)

        // Speed slider row
        let row = NSView(frame: NSRect(x: 40, y: 537, width: 400, height: 26))

        let slowLabel = makeLabel(text: "Slow", frame: NSRect(x: 0, y: 3, width: 35, height: 18), fontSize: 11, weight: .regular, color: .secondaryLabelColor)
        row.addSubview(slowLabel)

        let slider = NSSlider(value: WindowsMouse.shared.mouseSpeed, minValue: 0.5, maxValue: 3.0, target: self, action: #selector(mouseSpeedChanged))
        slider.frame = NSRect(x: 40, y: 0, width: 270, height: 26)
        slider.numberOfTickMarks = 0
        row.addSubview(slider)
        speedSlider = slider

        let fastLabel = makeLabel(text: "Fast", frame: NSRect(x: 315, y: 3, width: 35, height: 18), fontSize: 11, weight: .regular, color: .secondaryLabelColor)
        row.addSubview(fastLabel)

        let valLabel = makeLabel(text: String(format: "%.1fx", WindowsMouse.shared.mouseSpeed), frame: NSRect(x: 355, y: 3, width: 45, height: 18), fontSize: 11, weight: .medium)
        row.addSubview(valLabel)
        speedLabel = valLabel

        row.isHidden = !WindowsMouse.shared.accelEnabled
        contentView.addSubview(row)
        speedRow = row

        // --- Divider ---
        let div1 = NSBox(frame: NSRect(x: 30, y: 524, width: 420, height: 1))
        div1.boxType = .separator
        contentView.addSubview(div1)

        // --- Keyboard Shortcuts (embedded view) ---
        let shortcutsTitle = makeSectionTitle("Keyboard Shortcuts", y: 498)
        contentView.addSubview(shortcutsTitle)

        let shortcutsView = ShortcutPreferencesView(frame: NSRect(x: 40, y: 42, width: 400, height: 451))
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

    @objc private func toggleWindowsScroll(_ sender: NSButton) {
        WindowsMouse.shared.scrollEnabled = sender.state == .on
    }

    @objc private func toggleWindowsAccel(_ sender: NSButton) {
        let on = sender.state == .on
        WindowsMouse.shared.accelEnabled = on
        speedRow?.isHidden = !on
    }

    @objc private func mouseSpeedChanged(_ sender: NSSlider) {
        let value = sender.doubleValue
        WindowsMouse.shared.mouseSpeed = value
        speedLabel?.stringValue = String(format: "%.1fx", value)
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
