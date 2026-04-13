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

    static let standard = ZoneLayout(
        name: "Halvdeler",
        zones: [
            Zone(name: "Venstre", number: 1,
                 rectFraction: CGRect(x: 0, y: 0, width: 0.5, height: 1)),
            Zone(name: "Høyre", number: 2,
                 rectFraction: CGRect(x: 0.5, y: 0, width: 0.5, height: 1)),
        ]
    )
}
