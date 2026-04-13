// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BetterMac",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "BetterMac",
            path: "Sources/BetterMac",
            linkerSettings: [
                .linkedFramework("Cocoa"),
                .linkedFramework("Carbon"),
            ]
        ),
    ]
)
