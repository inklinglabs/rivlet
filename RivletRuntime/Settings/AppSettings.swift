import Foundation

/// Everything about a generated app the user can change after creation.
/// Stored as JSON in the app's support folder, never in the bundle, so a
/// change never invalidates the bundle signature.
public struct AppSettings: Codable, Sendable, Equatable {
    public var showToolbar = false
    public var badgeFromTitle = true
    public var badgeFromAPI = true
    public var notificationsEnabled = true
    public var keepRunningWhenWindowCloses = true
    public var allowedHosts: [String] = []
    /// nil means "the Safari string for this macOS".
    public var userAgent: String?
    public var zoom: Double = 1.0
    /// Window, menu bar, or floating. Added in 1.1; older runtimes ignore it.
    public var mode: AppMode = .window
    public var menuBar = MenuBarOptions()
    public var floating = FloatingOptions()

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case showToolbar, badgeFromTitle, badgeFromAPI, notificationsEnabled
        case keepRunningWhenWindowCloses, allowedHosts, userAgent, zoom
        case mode, menuBar, floating
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        showToolbar = try c.decodeIfPresent(Bool.self, forKey: .showToolbar) ?? d.showToolbar
        badgeFromTitle = try c.decodeIfPresent(Bool.self, forKey: .badgeFromTitle) ?? d.badgeFromTitle
        badgeFromAPI = try c.decodeIfPresent(Bool.self, forKey: .badgeFromAPI) ?? d.badgeFromAPI
        notificationsEnabled = try c.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? d.notificationsEnabled
        keepRunningWhenWindowCloses = try c.decodeIfPresent(Bool.self, forKey: .keepRunningWhenWindowCloses) ?? d.keepRunningWhenWindowCloses
        allowedHosts = try c.decodeIfPresent([String].self, forKey: .allowedHosts) ?? d.allowedHosts
        userAgent = try c.decodeIfPresent(String.self, forKey: .userAgent)
        zoom = try c.decodeIfPresent(Double.self, forKey: .zoom) ?? d.zoom
        // An unknown mode string from a newer runtime falls back to a window
        // rather than failing the whole decode.
        mode = (try? c.decodeIfPresent(String.self, forKey: .mode)).flatMap { $0 }.flatMap(AppMode.init(rawValue:)) ?? d.mode
        menuBar = try c.decodeIfPresent(MenuBarOptions.self, forKey: .menuBar) ?? d.menuBar
        floating = try c.decodeIfPresent(FloatingOptions.self, forKey: .floating) ?? d.floating
    }
}
