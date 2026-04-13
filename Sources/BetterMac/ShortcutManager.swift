import Cocoa

// MARK: - Shortcut Action

enum ShortcutAction: String, CaseIterable, Codable {
    // Window Snapping
    case snapLeft, snapRight, snapTop, snapBottom
    case snapTopLeft, snapTopRight, snapBottomLeft, snapBottomRight
    case center, maximize
    case dragModifier // modifier key for drag-to-snap

    // Tools
    case screenshot
    case screenshotCycleMode
    case zoneEditor
    case toggleOverlay
    case altTab

    var category: String {
        switch self {
        case .snapLeft, .snapRight, .snapTop, .snapBottom,
             .snapTopLeft, .snapTopRight, .snapBottomLeft, .snapBottomRight,
             .center, .maximize, .dragModifier:
            return "Window Snapping"
        case .screenshot, .screenshotCycleMode, .zoneEditor, .toggleOverlay, .altTab:
            return "Tools"
        }
    }

    var displayName: String {
        switch self {
        case .snapLeft: return "Snap Left"
        case .snapRight: return "Snap Right"
        case .snapTop: return "Snap Top"
        case .snapBottom: return "Snap Bottom"
        case .snapTopLeft: return "Snap Top Left"
        case .snapTopRight: return "Snap Top Right"
        case .snapBottomLeft: return "Snap Bottom Left"
        case .snapBottomRight: return "Snap Bottom Right"
        case .center: return "Center Window"
        case .maximize: return "Maximize Window"
        case .dragModifier: return "Drag Modifier Key"
        case .screenshot: return "Screenshot"
        case .screenshotCycleMode: return "Screenshot: Cycle Mode"
        case .zoneEditor: return "Edit Zones"
        case .toggleOverlay: return "Show Zone Overlay"
        case .altTab: return "Alt+Tab Switcher"
        }
    }

    static var categories: [(String, [ShortcutAction])] {
        let cats = Dictionary(grouping: allCases) { $0.category }
        return [
            ("Window Snapping", cats["Window Snapping"] ?? []),
            ("Tools", cats["Tools"] ?? []),
        ]
    }
}

// MARK: - Shortcut Binding

struct ShortcutBinding: Codable, Equatable, Hashable {
    let keyCode: Int64      // CGKeyCode, -1 for modifier-only
    let modifiers: UInt64   // CGEventFlags.rawValue (masked to relevant bits)

    static let relevantMask: UInt64 =
        CGEventFlags.maskShift.rawValue |
        CGEventFlags.maskControl.rawValue |
        CGEventFlags.maskAlternate.rawValue |
        CGEventFlags.maskCommand.rawValue

    init(keyCode: Int64, modifiers: UInt64) {
        self.keyCode = keyCode
        self.modifiers = modifiers & ShortcutBinding.relevantMask
    }

    init(keyCode: Int64, flags: CGEventFlags) {
        self.keyCode = keyCode
        self.modifiers = flags.rawValue & ShortcutBinding.relevantMask
    }

    var displayString: String {
        var parts: [String] = []
        if modifiers & CGEventFlags.maskControl.rawValue != 0 { parts.append("⌃") }
        if modifiers & CGEventFlags.maskAlternate.rawValue != 0 { parts.append("⌥") }
        if modifiers & CGEventFlags.maskShift.rawValue != 0 { parts.append("⇧") }
        if modifiers & CGEventFlags.maskCommand.rawValue != 0 { parts.append("⌘") }

        if keyCode == -1 {
            return parts.joined() + " + Drag"
        }

        let keyName = ShortcutBinding.keyCodeNames[Int(keyCode)] ?? "Key\(keyCode)"
        parts.append(keyName)
        return parts.joined()
    }

    static let keyCodeNames: [Int: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
        23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
        30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "↵",
        37: "L", 38: "J", 40: "K", 41: ";", 43: ",", 44: "/", 45: "N",
        46: "M", 47: ".", 48: "Tab", 49: "Space", 50: "`", 51: "⌫",
        53: "Esc", 96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8",
        101: "F9", 103: "F11", 105: "F13", 107: "F14", 109: "F10",
        111: "F12", 113: "F15", 118: "F4", 119: "F2", 120: "F1",
        121: "F16", 123: "←", 124: "→", 125: "↓", 126: "↑",
    ]
}

// MARK: - Shortcut Profile

struct ShortcutProfile: Codable, Identifiable {
    let id: UUID
    var name: String
    var bindings: [String: ShortcutBinding] // keyed by ShortcutAction.rawValue

    func binding(for action: ShortcutAction) -> ShortcutBinding? {
        bindings[action.rawValue]
    }
}

// MARK: - Shortcut Manager

final class ShortcutManager {
    static let shared = ShortcutManager()

    private(set) var profiles: [ShortcutProfile] = []
    private(set) var activeProfileId: UUID = UUID()
    private var reverseLookup: [ShortcutBinding: ShortcutAction] = [:]

    var activeProfile: ShortcutProfile {
        profiles.first(where: { $0.id == activeProfileId }) ?? profiles[0]
    }

    init() {
        load()
        if profiles.isEmpty {
            let defaultProfile = ShortcutProfile(
                id: UUID(),
                name: "Default",
                bindings: ShortcutManager.defaultBindings()
            )
            profiles = [defaultProfile]
            activeProfileId = defaultProfile.id
            save()
        }
        // Fill in any missing bindings (added in newer versions)
        fillMissingBindings()
        buildReverseLookup()
    }

    /// Ensure all profiles have correct bindings. Fixes corrupt/outdated values.
    private func fillMissingBindings() {
        let defaults = ShortcutManager.defaultBindings()
        var changed = false
        for i in 0..<profiles.count {
            for (key, binding) in defaults {
                if profiles[i].bindings[key] == nil {
                    profiles[i].bindings[key] = binding
                    changed = true
                }
            }
            // Fix corrupt bindings: if a binding has wrong modifier values, reset it
            for (key, binding) in profiles[i].bindings {
                if let defaultBinding = defaults[key] {
                    // If keyCode matches but modifiers don't, the binding is corrupt
                    if binding.keyCode == defaultBinding.keyCode && binding.modifiers != defaultBinding.modifiers {
                        profiles[i].bindings[key] = defaultBinding
                        changed = true
                    }
                }
            }
        }
        if changed { save() }
    }

    // MARK: - Lookup

    func action(forKeyCode keyCode: Int64, flags: CGEventFlags) -> ShortcutAction? {
        let binding = ShortcutBinding(keyCode: keyCode, flags: flags)
        return reverseLookup[binding]
    }

    func binding(for action: ShortcutAction) -> ShortcutBinding? {
        activeProfile.binding(for: action)
    }

    func dragModifierFlags() -> CGEventFlags {
        if let b = binding(for: .dragModifier) {
            return CGEventFlags(rawValue: b.modifiers)
        }
        return .maskShift
    }

    // MARK: - Mutation

    func updateBinding(_ action: ShortcutAction, to binding: ShortcutBinding) {
        guard let idx = profiles.firstIndex(where: { $0.id == activeProfileId }) else { return }
        profiles[idx].bindings[action.rawValue] = binding
        save()
        buildReverseLookup()
        NotificationCenter.default.post(name: .shortcutsChanged, object: nil)
    }

    func switchProfile(_ id: UUID) {
        activeProfileId = id
        save()
        buildReverseLookup()
        NotificationCenter.default.post(name: .shortcutsChanged, object: nil)
    }

    func createProfile(name: String, copyFrom: UUID? = nil) -> ShortcutProfile {
        let source = copyFrom.flatMap({ id in profiles.first(where: { $0.id == id }) })
        let bindings = source?.bindings ?? ShortcutManager.defaultBindings()
        let profile = ShortcutProfile(id: UUID(), name: name, bindings: bindings)
        profiles.append(profile)
        save()
        return profile
    }

    func deleteProfile(_ id: UUID) {
        profiles.removeAll { $0.id == id }
        if activeProfileId == id {
            activeProfileId = profiles.first?.id ?? UUID()
            buildReverseLookup()
        }
        save()
    }

    func renameProfile(_ id: UUID, to name: String) {
        guard let idx = profiles.firstIndex(where: { $0.id == id }) else { return }
        profiles[idx].name = name
        save()
    }

    func resetActiveToDefaults() {
        guard let idx = profiles.firstIndex(where: { $0.id == activeProfileId }) else { return }
        profiles[idx].bindings = ShortcutManager.defaultBindings()
        save()
        buildReverseLookup()
        NotificationCenter.default.post(name: .shortcutsChanged, object: nil)
    }

    // MARK: - Persistence

    private static let profilesKey = "shortcutProfiles"
    private static let activeKey = "shortcutActiveProfileId"

    func save() {
        if let data = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(data, forKey: ShortcutManager.profilesKey)
        }
        UserDefaults.standard.set(activeProfileId.uuidString, forKey: ShortcutManager.activeKey)
    }

    func load() {
        if let data = UserDefaults.standard.data(forKey: ShortcutManager.profilesKey),
           let decoded = try? JSONDecoder().decode([ShortcutProfile].self, from: data) {
            profiles = decoded
        }
        if let idStr = UserDefaults.standard.string(forKey: ShortcutManager.activeKey),
           let id = UUID(uuidString: idStr) {
            activeProfileId = id
        }
    }

    private func buildReverseLookup() {
        reverseLookup.removeAll()
        for (key, binding) in activeProfile.bindings {
            if let action = ShortcutAction(rawValue: key), action != .dragModifier {
                reverseLookup[binding] = action
            }
        }
    }

    // MARK: - Defaults

    static func defaultBindings() -> [String: ShortcutBinding] {
        let ctrl_opt: UInt64 = CGEventFlags.maskControl.rawValue | CGEventFlags.maskAlternate.rawValue
        let shift_opt: UInt64 = CGEventFlags.maskShift.rawValue | CGEventFlags.maskAlternate.rawValue
        let opt: UInt64 = CGEventFlags.maskAlternate.rawValue
        let shift: UInt64 = CGEventFlags.maskShift.rawValue

        return [
            ShortcutAction.snapLeft.rawValue:       ShortcutBinding(keyCode: 123, modifiers: ctrl_opt),
            ShortcutAction.snapRight.rawValue:      ShortcutBinding(keyCode: 124, modifiers: ctrl_opt),
            ShortcutAction.snapTop.rawValue:        ShortcutBinding(keyCode: 126, modifiers: ctrl_opt),
            ShortcutAction.snapBottom.rawValue:     ShortcutBinding(keyCode: 125, modifiers: ctrl_opt),
            ShortcutAction.snapTopLeft.rawValue:    ShortcutBinding(keyCode: 32, modifiers: ctrl_opt),
            ShortcutAction.snapTopRight.rawValue:   ShortcutBinding(keyCode: 34, modifiers: ctrl_opt),
            ShortcutAction.snapBottomLeft.rawValue: ShortcutBinding(keyCode: 38, modifiers: ctrl_opt),
            ShortcutAction.snapBottomRight.rawValue:ShortcutBinding(keyCode: 40, modifiers: ctrl_opt),
            ShortcutAction.center.rawValue:         ShortcutBinding(keyCode: 8, modifiers: ctrl_opt),
            ShortcutAction.maximize.rawValue:       ShortcutBinding(keyCode: 36, modifiers: ctrl_opt),
            ShortcutAction.toggleOverlay.rawValue:  ShortcutBinding(keyCode: 6, modifiers: ctrl_opt),
            ShortcutAction.zoneEditor.rawValue:     ShortcutBinding(keyCode: 14, modifiers: ctrl_opt),
            ShortcutAction.screenshot.rawValue:     ShortcutBinding(keyCode: 1, modifiers: shift_opt),
            ShortcutAction.screenshotCycleMode.rawValue: ShortcutBinding(keyCode: 49, modifiers: shift_opt), // ⇧⌥Space
            ShortcutAction.altTab.rawValue:         ShortcutBinding(keyCode: 48, modifiers: opt),
            ShortcutAction.dragModifier.rawValue:   ShortcutBinding(keyCode: -1, modifiers: shift),
        ]
    }
}

extension Notification.Name {
    static let shortcutsChanged = Notification.Name("shortcutsChanged")
}
