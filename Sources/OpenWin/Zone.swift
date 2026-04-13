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

    /// The currently active layout
    static var current: ZoneLayout = loadSaved() ?? presets[0] {
        didSet { save(current) }
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

    // MARK: - Persistence

    private static let saveKey = "savedZoneLayout"

    private static func save(_ layout: ZoneLayout) {
        var data: [[String: CGFloat]] = []
        for zone in layout.zones {
            data.append([
                "x": zone.rectFraction.origin.x,
                "y": zone.rectFraction.origin.y,
                "w": zone.rectFraction.width,
                "h": zone.rectFraction.height,
            ])
        }
        UserDefaults.standard.set(data, forKey: saveKey)
        UserDefaults.standard.set(layout.name, forKey: saveKey + "_name")
    }

    private static func loadSaved() -> ZoneLayout? {
        guard let data = UserDefaults.standard.array(forKey: saveKey) as? [[String: CGFloat]],
              !data.isEmpty else { return nil }
        let name = UserDefaults.standard.string(forKey: saveKey + "_name") ?? "Custom"
        let zones = data.enumerated().map { (i, d) in
            Zone(
                name: "Zone \(i + 1)",
                number: i + 1,
                rectFraction: CGRect(
                    x: d["x"] ?? 0, y: d["y"] ?? 0,
                    width: d["w"] ?? 1, height: d["h"] ?? 1
                )
            )
        }
        return ZoneLayout(name: name, zones: zones)
    }
}
