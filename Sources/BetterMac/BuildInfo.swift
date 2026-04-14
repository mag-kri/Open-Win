import Foundation

enum BuildInfo {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    static var localBuildCode: String {
        Bundle.main.object(forInfoDictionaryKey: "BetterMacLocalBuildCode") as? String ?? "local-dev"
    }

    static var bundlePath: String {
        Bundle.main.bundleURL.path
    }

    static var shortBundlePath: String {
        let path = bundlePath
        let home = NSHomeDirectory()
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}
