// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OpenWin",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "OpenWin",
            path: "Sources/OpenWin",
            linkerSettings: [
                .linkedFramework("Cocoa"),
                .linkedFramework("Carbon"),
            ]
        ),
    ]
)
