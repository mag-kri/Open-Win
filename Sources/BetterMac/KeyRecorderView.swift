import Cocoa

/// Click-to-record shortcut field. Click → press keys → binding saved.
final class KeyRecorderView: NSView {
    var currentBinding: ShortcutBinding? {
        didSet { needsDisplay = true }
    }
    var onBindingChanged: ((ShortcutBinding) -> Void)?
    var isModifierOnly = false // for dragModifier

    private var isRecording = false
    private var localMonitor: Any?

    override init(frame: CGRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 5
        layer?.borderWidth = 1
        updateAppearance()

        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(area)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func updateAppearance() {
        if isRecording {
            layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.15).cgColor
            layer?.borderColor = NSColor.systemBlue.cgColor
        } else {
            layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
            layer?.borderColor = NSColor.separatorColor.cgColor
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let text: String
        let color: NSColor

        if isRecording {
            text = isModifierOnly ? "Press modifier key..." : "Press shortcut..."
            color = .systemBlue
        } else if let binding = currentBinding {
            text = binding.displayString
            color = .labelColor
        } else {
            text = "Click to set"
            color = .tertiaryLabelColor
        }

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: color,
        ]
        let size = text.size(withAttributes: attrs)
        let point = CGPoint(
            x: (bounds.width - size.width) / 2,
            y: (bounds.height - size.height) / 2
        )
        text.draw(at: point, withAttributes: attrs)
    }

    override func mouseDown(with event: NSEvent) {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        updateAppearance()
        needsDisplay = true

        // Pause hotkey handling so keys reach us
        HotkeyManager.shared.paused = true

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self = self, self.isRecording else { return event }

            if event.type == .keyDown {
                if event.keyCode == 53 { // Escape — cancel
                    self.stopRecording()
                    return nil
                }
                if event.keyCode == 51 { // Backspace — clear
                    self.currentBinding = nil
                    self.onBindingChanged?(ShortcutBinding(keyCode: -2, modifiers: 0)) // sentinel for "cleared"
                    self.stopRecording()
                    return nil
                }

                if !self.isModifierOnly {
                    // Normal shortcut: capture key + modifiers
                    var mods: UInt64 = 0
                    if event.modifierFlags.contains(.shift) { mods |= CGEventFlags.maskShift.rawValue }
                    if event.modifierFlags.contains(.option) { mods |= CGEventFlags.maskAlternate.rawValue }
                    if event.modifierFlags.contains(.control) { mods |= CGEventFlags.maskControl.rawValue }
                    if event.modifierFlags.contains(.command) { mods |= CGEventFlags.maskCommand.rawValue }

                    let binding = ShortcutBinding(keyCode: Int64(event.keyCode), modifiers: mods)
                    self.currentBinding = binding
                    self.onBindingChanged?(binding)
                    self.stopRecording()
                    return nil
                }
            }

            if event.type == .flagsChanged && self.isModifierOnly {
                // Modifier-only binding (for drag modifier)
                var mods: UInt64 = 0
                if event.modifierFlags.contains(.shift) { mods |= CGEventFlags.maskShift.rawValue }
                if event.modifierFlags.contains(.option) { mods |= CGEventFlags.maskAlternate.rawValue }
                if event.modifierFlags.contains(.control) { mods |= CGEventFlags.maskControl.rawValue }
                if event.modifierFlags.contains(.command) { mods |= CGEventFlags.maskCommand.rawValue }

                if mods != 0 {
                    let binding = ShortcutBinding(keyCode: -1, modifiers: mods)
                    self.currentBinding = binding
                    self.onBindingChanged?(binding)
                    self.stopRecording()
                    return nil
                }
            }

            return event
        }
    }

    private func stopRecording() {
        isRecording = false
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
        updateAppearance()
        needsDisplay = true

        // Resume hotkey handling
        HotkeyManager.shared.paused = false
    }

    override func mouseEntered(with event: NSEvent) {
        if !isRecording {
            layer?.borderColor = NSColor.systemBlue.withAlphaComponent(0.5).cgColor
        }
    }

    override func mouseExited(with event: NSEvent) {
        if !isRecording {
            layer?.borderColor = NSColor.separatorColor.cgColor
        }
    }
}
