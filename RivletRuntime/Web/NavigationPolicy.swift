import Foundation

/// Decides whether a navigation stays inside the generated app or goes to
/// the default browser. Pure value type so it is fully unit tested.
public struct NavigationPolicy: Sendable, Equatable {
    public enum Decision: Sendable, Equatable {
        case stayInApp
        case openExternally
    }

    public let appDomain: String
    public let allowedHosts: [String]

    public init(appURL: URL, allowedHosts: [String]) {
        self.appDomain = Self.registrableDomain(of: appURL.host()?.lowercased() ?? "")
        self.allowedHosts = allowedHosts.map { $0.lowercased() }
    }

    /// Hosts that every app may visit, because sign-in flows bounce through
    /// them. Kept short and boring.
    public static let universalSignInHosts: [String] = [
        "accounts.google.com", "accounts.youtube.com", "myaccount.google.com",
        "login.microsoftonline.com", "login.live.com", "login.microsoft.com",
        "appleid.apple.com", "idmsa.apple.com",
        "id.atlassian.com", ".okta.com", ".auth0.com",
    ]

    /// Extra hosts worth seeding into a new app's allowed list based on
    /// where it points. The user can edit the list afterwards.
    public static func seededAllowedHosts(for url: URL) -> [String] {
        let host = url.host()?.lowercased() ?? ""
        var hosts: [String] = []
        if host.hasSuffix("google.com") || host.hasSuffix("youtube.com") {
            hosts += [".google.com", ".googleusercontent.com", ".gstatic.com"]
        }
        if host.hasSuffix("microsoft.com") || host.hasSuffix("office.com") || host.hasSuffix("live.com") {
            hosts += [".microsoft.com", ".office.com", ".live.com", ".office365.com", ".sharepoint.com"]
        }
        if host.hasSuffix("slack.com") {
            hosts += [".slack.com", ".slack-edge.com"]
        }
        return hosts
    }

    public func isAllowed(host rawHost: String?) -> Bool {
        guard let host = rawHost?.lowercased(), !host.isEmpty else { return true }
        if Self.registrableDomain(of: host) == appDomain { return true }
        for pattern in allowedHosts + Self.universalSignInHosts {
            if pattern.hasPrefix(".") {
                if host == String(pattern.dropFirst()) || host.hasSuffix(pattern) { return true }
            } else if host == pattern {
                return true
            }
        }
        return false
    }

    /// `isUserLinkClick` is true for a click on a link (including
    /// `target=_blank` and popups). Redirects and form posts are never sent
    /// outside, because sign-in flows depend on them.
    public func decision(for url: URL, isUserLinkClick: Bool) -> Decision {
        guard let scheme = url.scheme?.lowercased() else { return .stayInApp }
        if scheme != "http" && scheme != "https" && scheme != "about" && scheme != "blob" && scheme != "data" {
            return .openExternally
        }
        if isAllowed(host: url.host()) { return .stayInApp }
        return isUserLinkClick ? .openExternally : .stayInApp
    }

    private static let twoLevelSuffixes: Set<String> = [
        "co.uk", "org.uk", "gov.uk", "ac.uk", "me.uk", "ltd.uk",
        "com.au", "net.au", "org.au", "edu.au", "gov.au",
        "co.nz", "org.nz", "net.nz", "co.jp", "or.jp", "ne.jp", "ac.jp",
        "com.br", "com.mx", "com.ar", "co.in", "co.za", "co.kr", "com.sg",
        "com.hk", "com.tw", "com.tr", "com.cn", "com.ua", "co.il", "com.my",
    ]

    /// `mail.google.com` -> `google.com`, `www.bbc.co.uk` -> `bbc.co.uk`.
    public static func registrableDomain(of host: String) -> String {
        let labels = host.lowercased().split(separator: ".").map(String.init)
        guard labels.count > 2 else { return host.lowercased() }
        if labels.allSatisfy({ Int($0) != nil }) { return host.lowercased() }
        let lastTwo = labels.suffix(2).joined(separator: ".")
        if twoLevelSuffixes.contains(lastTwo), labels.count >= 3 {
            return labels.suffix(3).joined(separator: ".")
        }
        return lastTwo
    }
}
