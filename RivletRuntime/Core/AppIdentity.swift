import Foundation

/// What a generated app is. Read once from the host bundle's Info.plist and
/// never changed after creation. Everything editable lives in `AppSettings`.
public struct AppIdentity: Sendable, Equatable {
    public let bundleIdentifier: String
    public let name: String
    public let url: URL
    public let bundleURL: URL

    public init(bundleIdentifier: String, name: String, url: URL, bundleURL: URL) {
        self.bundleIdentifier = bundleIdentifier
        self.name = name
        self.url = url
        self.bundleURL = bundleURL
    }

    /// Reads the identity out of a bundle. Returns nil when the bundle was
    /// not made by Rivlet (no `RivletApp` key) or has no usable URL.
    public init?(bundle: Bundle) {
        guard let info = bundle.infoDictionary,
              info[InfoKey.rivletApp] as? Bool == true,
              let identifier = bundle.bundleIdentifier,
              let urlString = info[InfoKey.rivletURL] as? String,
              let url = URL(string: urlString),
              url.scheme == "http" || url.scheme == "https"
        else { return nil }
        let name = (info["CFBundleDisplayName"] as? String)
            ?? (info["CFBundleName"] as? String)
            ?? url.host() ?? "Rivlet App"
        self.init(bundleIdentifier: identifier, name: name, url: url, bundleURL: bundle.bundleURL)
    }

    public enum InfoKey {
        public static let rivletApp = "RivletApp"
        public static let rivletURL = "RivletURL"
        public static let templateVersion = "RivletTemplateVersion"
    }
}
