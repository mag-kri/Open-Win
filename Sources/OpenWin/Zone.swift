import Cocoa

struct Zone {
    let name: String
    let number: Int
    let rectFraction: CGRect // fractions of screen (0.0 - 1.0)

    func frame(for screenFrame: CGRect) -> CGRect {
        CGRect(
            x: screenFrame.origin.x + screenFrame.width * rectFraction.origin.x,
            y: screenFrame.origin.y + screenFrame.height * rectFraction.origin.y,
            width: screenFrame.width * rectFraction.width,
            height: screenFrame.height * rectFraction.height
        )
    }
}

struct ZoneLayout {
    let name: String
    let zones: [Zone]

    /// Get layout for a specific screen (by screen number/index)
    static func current(for screen: NSScreen? = nil) -> ZoneLayout {
        let key = screenKey(for: screen ?? NSScreen.main)
        return loadForScreen(key) ?? presets[0]
    }

    /// Set layout for a specific screen
    static func setCurrent(_ layout: ZoneLayout, for screen: NSScreen? = nil) {
        let key = screenKey(for: screen ?? NSScreen.main)
        saveForScreen(key, layout: layout)
    }

    /// Convenience for main screen
    static var current: ZoneLayout {
        get { current(for: NSScreen.main) }
        set { setCurrent(newValue, for: NSScreen.main) }
    }

    // MARK: - Screen key

    private static func screenKey(for screen: NSScreen?) -> String {
        guard let screen = screen else { return "main" }
        let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
        return "screen_\(id)"
    }

    // MARK: - Presets

    static let presets: [ZoneLayout] = [
        ZoneLayout(name: "Halves", zones: [
            Zone(name: "Left", number: 1, rectFraction: CGRect(x: 0, y: 0, width: 0.5, height: 1)),
            Zone(name: "Right", number: 2, rectFraction: CGRect(x: 0.5, y: 0, width: 0.5, height: 1)),
        ]),
        ZoneLayout(name: "Thirds", zones: [
            Zone(name: "Left", number: 1, rectFraction: CGRect(x: 0, y: 0, width: 0.333, height: 1)),
            Zone(name: "Center", number: 2, rectFraction: CGRect(x: 0.333, y: 0, width: 0.334, height: 1)),
            Zone(name: "Right", number: 3, rectFraction: CGRect(x: 0.667, y: 0, width: 0.333, height: 1)),
        ]),
        ZoneLayout(name: "Grid 2x2", zones: [
            Zone(name: "Top Left", number: 1, rectFraction: CGRect(x: 0, y: 0, width: 0.5, height: 0.5)),
            Zone(name: "Top Right", number: 2, rectFraction: CGRect(x: 0.5, y: 0, width: 0.5, height: 0.5)),
            Zone(name: "Bottom Left", number: 3, rectFraction: CGRect(x: 0, y: 0.5, width: 0.5, height: 0.5)),
            Zone(name: "Bottom Right", number: 4, rectFraction: CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5)),
        ]),
        ZoneLayout(name: "Focus + Sides", zones: [
            Zone(name: "Left", number: 1, rectFraction: CGRect(x: 0, y: 0, width: 0.2, height: 1)),
            Zone(name: "Center", number: 2, rectFraction: CGRect(x: 0.2, y: 0, width: 0.6, height: 1)),
            Zone(name: "Right", number: 3, rectFraction: CGRect(x: 0.8, y: 0, width: 0.2, height: 1)),
        ]),
        ZoneLayout(name: "Widescreen", zones: [
            Zone(name: "Left", number: 1, rectFraction: CGRect(x: 0, y: 0, width: 0.25, height: 1)),
            Zone(name: "Center Left", number: 2, rectFraction: CGRect(x: 0.25, y: 0, width: 0.25, height: 1)),
            Zone(name: "Center Right", number: 3, rectFraction: CGRect(x: 0.5, y: 0, width: 0.25, height: 1)),
            Zone(name: "Right", number: 4, rectFraction: CGRect(x: 0.75, y: 0, width: 0.25, height: 1)),
        ]),
        ZoneLayout(name: "Main + Stack", zones: [
            Zone(name: "Main", number: 1, rectFraction: CGRect(x: 0, y: 0, width: 0.65, height: 1)),
            Zone(name: "Top Right", number: 2, rectFraction: CGRect(x: 0.65, y: 0, width: 0.35, height: 0.5)),
            Zone(name: "Bottom Right", number: 3, rectFraction: CGRect(x: 0.65, y: 0.5, width: 0.35, height: 0.5)),
        ]),
    ]

    // MARK: - Per-screen persistence

    private static func saveForScreen(_ key: String, layout: ZoneLayout) {
        let data = encodeLayout(layout)
        UserDefaults.standard.set(data, forKey: "layout_\(key)")
        UserDefaults.standard.set(layout.name, forKey: "layout_\(key)_name")
    }

    private static func loadForScreen(_ key: String) -> ZoneLayout? {
        guard let data = UserDefaults.standard.array(forKey: "layout_\(key)") as? [[String: CGFloat]],
              !data.isEmpty else { return nil }
        let name = UserDefaults.standard.string(forKey: "layout_\(key)_name") ?? "Custom"
        return decodeLayout(name: name, data: data)
    }

    // MARK: - Custom saved layouts

    static func savedLayouts() -> [ZoneLayout] {
        guard let all = UserDefaults.standard.array(forKey: "customLayouts") as? [[String: Any]] else { return [] }
        return all.compactMap { entry in
            guard let name = entry["name"] as? String,
                  let zones = entry["zones"] as? [[String: CGFloat]] else { return nil }
            return decodeLayout(name: name, data: zones)
        }
    }

    static func saveCustomLayout(_ layout: ZoneLayout) {
        var all = UserDefaults.standard.array(forKey: "customLayouts") as? [[String: Any]] ?? []
        all.removeAll { ($0["name"] as? String) == layout.name }
        all.append(["name": layout.name, "zones": encodeLayout(layout)])
        UserDefaults.standard.set(all, forKey: "customLayouts")
    }

    static func deleteCustomLayout(name: String) {
        var all = UserDefaults.standard.array(forKey: "customLayouts") as? [[String: Any]] ?? []
        all.removeAll { ($0["name"] as? String) == name }
        UserDefaults.standard.set(all, forKey: "customLayouts")
    }

    // MARK: - Encode/Decode

    private static func encodeLayout(_ layout: ZoneLayout) -> [[String: CGFloat]] {
        layout.zones.map { z in
            ["x": z.rectFraction.origin.x, "y": z.rectFraction.origin.y,
             "w": z.rectFraction.width, "h": z.rectFraction.height]
        }
    }

    private static func decodeLayout(name: String, data: [[String: CGFloat]]) -> ZoneLayout {
        let zones = data.enumerated().map { (i, d) in
            Zone(name: "Zone \(i + 1)", number: i + 1,
                 rectFraction: CGRect(x: d["x"] ?? 0, y: d["y"] ?? 0,
                                      width: d["w"] ?? 1, height: d["h"] ?? 1))
        }
        return ZoneLayout(name: name, zones: zones)
    }
}
