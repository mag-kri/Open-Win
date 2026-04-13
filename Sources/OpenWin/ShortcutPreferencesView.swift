import Cocoa

/// Preferences panel with profile picker and editable shortcut rows grouped by category.
final class ShortcutPreferencesView: NSView {
    private var profilePopup: NSPopUpButton!
    private var recorderRows: [(ShortcutAction, KeyRecorderView)] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        buildUI()

        NotificationCenter.default.addObserver(self, selector: #selector(refreshAll), name: .shortcutsChanged, object: nil)

        // Refresh when keyboards change
        KeyboardDetector.shared.onKeyboardsChanged = { [weak self] in
            self?.refreshProfilePopup()
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildUI() {
        subviews.forEach { $0.removeFromSuperview() }
        recorderRows.removeAll()

        let sm = ShortcutManager.shared
        var y = bounds.height - 8

        // Profile selector
        y -= 26
        let profileLabel = makeLabel(text: "Profile:", frame: NSRect(x: 0, y: y, width: 50, height: 22), size: 12, weight: .medium)
        addSubview(profileLabel)

        profilePopup = NSPopUpButton(frame: NSRect(x: 55, y: y - 2, width: 160, height: 24))
        profilePopup.font = .systemFont(ofSize: 11)
        refreshProfilePopup()
        profilePopup.target = self
        profilePopup.action = #selector(profileChanged)
        addSubview(profilePopup)

        let addBtn = NSButton(frame: NSRect(x: 220, y: y - 1, width: 24, height: 22))
        addBtn.title = "+"
        addBtn.bezelStyle = .rounded
        addBtn.font = .systemFont(ofSize: 13, weight: .bold)
        addBtn.target = self
        addBtn.action = #selector(addProfile)
        addSubview(addBtn)

        let delBtn = NSButton(frame: NSRect(x: 247, y: y - 1, width: 24, height: 22))
        delBtn.title = "−"
        delBtn.bezelStyle = .rounded
        delBtn.font = .systemFont(ofSize: 13, weight: .bold)
        delBtn.target = self
        delBtn.action = #selector(deleteProfile)
        addSubview(delBtn)

        let renameBtn = NSButton(frame: NSRect(x: 278, y: y - 1, width: 65, height: 22))
        renameBtn.title = "Rename"
        renameBtn.bezelStyle = .rounded
        renameBtn.font = .systemFont(ofSize: 10)
        renameBtn.target = self
        renameBtn.action = #selector(renameProfile)
        addSubview(renameBtn)

        y -= 6

        // Connected keyboards info
        let kbs = KeyboardDetector.shared.keyboards
        if !kbs.isEmpty {
            let kbText = kbs.map { "\($0.name) (\($0.transport))" }.joined(separator: ", ")
            let kbLabel = makeLabel(text: "Connected: \(kbText)", frame: NSRect(x: 0, y: y - 14, width: 400, height: 14), size: 9, weight: .regular, color: .tertiaryLabelColor)
            addSubview(kbLabel)
            y -= 18
        }

        y -= 4

        // Shortcut rows grouped by category
        for (category, actions) in ShortcutAction.categories {
            y -= 22
            let catLabel = makeLabel(text: category, frame: NSRect(x: 0, y: y, width: 300, height: 18), size: 12, weight: .semibold, color: .secondaryLabelColor)
            addSubview(catLabel)

            for action in actions {
                y -= 24
                let nameLabel = makeLabel(text: action.displayName, frame: NSRect(x: 10, y: y, width: 180, height: 20), size: 11, weight: .regular)
                addSubview(nameLabel)

                let recorder = KeyRecorderView(frame: NSRect(x: 200, y: y - 2, width: 180, height: 24))
                recorder.currentBinding = sm.activeProfile.binding(for: action)
                recorder.isModifierOnly = (action == .dragModifier)
                recorder.onBindingChanged = { [weak self] binding in
                    if binding.keyCode == -2 { return } // cleared
                    ShortcutManager.shared.updateBinding(action, to: binding)
                    self?.refreshRecorders()
                }
                addSubview(recorder)
                recorderRows.append((action, recorder))
            }

            y -= 6
        }

        // Reset button
        y -= 28
        let resetBtn = NSButton(frame: NSRect(x: 0, y: y, width: 130, height: 24))
        resetBtn.title = "Reset to Defaults"
        resetBtn.bezelStyle = .rounded
        resetBtn.font = .systemFont(ofSize: 11)
        resetBtn.target = self
        resetBtn.action = #selector(resetDefaults)
        addSubview(resetBtn)
    }

    private func refreshRecorders() {
        let sm = ShortcutManager.shared
        for (action, recorder) in recorderRows {
            recorder.currentBinding = sm.activeProfile.binding(for: action)
        }
    }

    private func refreshProfilePopup() {
        let sm = ShortcutManager.shared
        profilePopup.removeAllItems()
        for profile in sm.profiles {
            profilePopup.addItem(withTitle: profile.name)
        }
        if let idx = sm.profiles.firstIndex(where: { $0.id == sm.activeProfileId }) {
            profilePopup.selectItem(at: idx)
        }
    }

    @objc private func profileChanged() {
        let sm = ShortcutManager.shared
        let idx = profilePopup.indexOfSelectedItem
        guard idx < sm.profiles.count else { return }
        sm.switchProfile(sm.profiles[idx].id)
        refreshRecorders()
    }

    @objc private func addProfile() {
        let alert = NSAlert()
        alert.messageText = "New Profile"
        alert.informativeText = "Enter a name for the new profile:"
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        input.stringValue = "New Profile"
        alert.accessoryView = input

        if alert.runModal() == .alertFirstButtonReturn {
            let name = input.stringValue.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { return }
            let profile = ShortcutManager.shared.createProfile(name: name, copyFrom: ShortcutManager.shared.activeProfileId)
            ShortcutManager.shared.switchProfile(profile.id)
            refreshProfilePopup()
            refreshRecorders()
        }
    }

    @objc private func deleteProfile() {
        let sm = ShortcutManager.shared
        guard sm.profiles.count > 1 else {
            NSSound.beep()
            return
        }
        sm.deleteProfile(sm.activeProfileId)
        refreshProfilePopup()
        refreshRecorders()
    }

    @objc private func renameProfile() {
        let sm = ShortcutManager.shared
        let alert = NSAlert()
        alert.messageText = "Rename Profile"
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        input.stringValue = sm.activeProfile.name
        alert.accessoryView = input

        if alert.runModal() == .alertFirstButtonReturn {
            let name = input.stringValue.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { return }
            sm.renameProfile(sm.activeProfileId, to: name)
            refreshProfilePopup()
        }
    }

    @objc private func resetDefaults() {
        ShortcutManager.shared.resetActiveToDefaults()
        refreshRecorders()
    }

    @objc private func refreshAll() {
        refreshRecorders()
    }

    private func makeLabel(text: String, frame: NSRect, size: CGFloat, weight: NSFont.Weight, color: NSColor = .labelColor) -> NSTextField {
        let l = NSTextField(frame: frame)
        l.stringValue = text; l.font = .systemFont(ofSize: size, weight: weight)
        l.textColor = color; l.isBezeled = false; l.isEditable = false; l.drawsBackground = false
        return l
    }
}
