import Foundation

/// Every path Rivlet and its generated apps write to, in one place.
public enum RivletPaths {
    public static let makerBundleIdentifier = "com.inklinglabs.rivlet"
    public static let generatedBundlePrefix = "com.inklinglabs.rivlet.app."
    public static let releasesURL = URL(string: "https://github.com/inklinglabs/rivlet/releases/latest")!

    /// `~/Library/Application Support/Rivlet`
    public static var supportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appending(path: "Rivlet", directoryHint: .isDirectory)
    }

    /// `~/Library/Application Support/Rivlet/apps.json`, the maker's registry.
    public static var registryFile: URL {
        supportDirectory.appending(path: "apps.json")
    }

    /// `~/Library/Application Support/Rivlet/Apps/<bundle id>/`
    public static func appDirectory(for bundleIdentifier: String) -> URL {
        supportDirectory
            .appending(path: "Apps", directoryHint: .isDirectory)
            .appending(path: bundleIdentifier, directoryHint: .isDirectory)
    }

    /// `~/Applications`, the default home for generated apps.
    public static var userApplications: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Applications", directoryHint: .isDirectory)
    }

    public static func ensureDirectory(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}
