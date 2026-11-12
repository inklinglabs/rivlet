import Foundation
import Testing
@testable import RivletRuntime

/// The 1.0.x settings shape, frozen here so the tests can prove that a
/// settings file written by 1.1 still decodes on an older runtime.
private struct LegacyAppSettings: Codable, Equatable {
    var showToolbar = false
    var badgeFromTitle = true
    var badgeFromAPI = true
    var notificationsEnabled = true
    var keepRunningWhenWindowCloses = true
    var allowedHosts: [String] = []
    var userAgent: String?
    var zoom: Double = 1.0

    private enum CodingKeys: String, CodingKey {
        case showToolbar, badgeFromTitle, badgeFromAPI, notificationsEnabled
        case keepRunningWhenWindowCloses, allowedHosts, userAgent, zoom
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = LegacyAppSettings()
        showToolbar = try c.decodeIfPresent(Bool.self, forKey: .showToolbar) ?? d.showToolbar
        badgeFromTitle = try c.decodeIfPresent(Bool.self, forKey: .badgeFromTitle) ?? d.badgeFromTitle
        badgeFromAPI = try c.decodeIfPresent(Bool.self, forKey: .badgeFromAPI) ?? d.badgeFromAPI
        notificationsEnabled = try c.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? d.notificationsEnabled
        keepRunningWhenWindowCloses = try c.decodeIfPresent(Bool.self, forKey: .keepRunningWhenWindowCloses) ?? d.keepRunningWhenWindowCloses
        allowedHosts = try c.decodeIfPresent([String].self, forKey: .allowedHosts) ?? d.allowedHosts
        userAgent = try c.decodeIfPresent(String.self, forKey: .userAgent)
        zoom = try c.decodeIfPresent(Double.self, forKey: .zoom) ?? d.zoom
    }
}

@Suite struct AppModeTests {
    @Test func legacyFileDecodesAsWindowMode() throws {
        let data = Data(#"{"allowedHosts":["a.com"],"showToolbar":true,"zoom":1.2}"#.utf8)
        let settings = try JSONDecoder().decode(AppSettings.self, from: data)
        #expect(settings.mode == .window)
        #expect(settings.menuBar == MenuBarOptions())
        #expect(settings.floating == FloatingOptions())
        #expect(settings.allowedHosts == ["a.com"])
        #expect(settings.zoom == 1.2)
    }

    @Test func newFileDecodesOnLegacyRuntime() throws {
        var settings = AppSettings()
        settings.mode = .menuBar
        settings.menuBar.hotkey = Hotkey(keyCode: 49, modifiers: Hotkey.Modifier.command | Hotkey.Modifier.shift)
        settings.menuBar.popoverSize = PopoverSize(width: 500, height: 700)
        settings.floating.allSpaces = true
        settings.allowedHosts = ["b.com"]
        settings.userAgent = "Custom"
        settings.zoom = 0.9
        let data = try JSONEncoder().encode(settings)

        let legacy = try JSONDecoder().decode(LegacyAppSettings.self, from: data)
        #expect(legacy.allowedHosts == ["b.com"])
        #expect(legacy.userAgent == "Custom")
        #expect(legacy.zoom == 0.9)
        #expect(legacy.showToolbar == false)
    }

    @Test func modeAndOptionsRoundTrip() throws {
        var settings = AppSettings()
        settings.mode = .floating
        settings.floating.allSpaces = true
        settings.menuBar.hideDockIcon = false
        settings.menuBar.hotkey = Hotkey(keyCode: 9, modifiers: Hotkey.Modifier.option)
        let data = try JSONEncoder().encode(settings)
        let again = try JSONDecoder().decode(AppSettings.self, from: data)
        #expect(again == settings)
    }

    @Test func unknownModeFallsBackToWindow() throws {
        let data = Data(#"{"mode":"hologram","showToolbar":true}"#.utf8)
        let settings = try JSONDecoder().decode(AppSettings.self, from: data)
        #expect(settings.mode == .window)
        #expect(settings.showToolbar == true)
    }

    @Test func partialMenuBarOptionsKeepDefaults() throws {
        let data = Data(#"{"mode":"menuBar","menuBar":{"hideDockIcon":false}}"#.utf8)
        let settings = try JSONDecoder().decode(AppSettings.self, from: data)
        #expect(settings.mode == .menuBar)
        #expect(settings.menuBar.hideDockIcon == false)
        #expect(settings.menuBar.hotkey == nil)
        #expect(settings.menuBar.popoverSize == .default)
    }

    @Test func hotkeyNeedsAModifier() {
        #expect(Hotkey(keyCode: 0, modifiers: 0).hasModifier == false)
        #expect(Hotkey(keyCode: 0, modifiers: Hotkey.Modifier.command).hasModifier == true)
        #expect(Hotkey(keyCode: 0, modifiers: 1 << 16).hasModifier == false)
    }

    @Test @MainActor func loadingALegacyFileDoesNotRewriteIt() throws {
        let dir = FileManager.default.temporaryDirectory.appending(path: "rivlet-mode-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appending(path: "settings.json")
        let original = Data(#"{"allowedHosts":["a.com"]}"#.utf8)
        try original.write(to: file)
        let store = SettingsStore(bundleIdentifier: "com.inklinglabs.rivlet.app.test", directory: dir)
        #expect(store.settings.mode == .window)
        #expect(try Data(contentsOf: file) == original)
        store.settings.mode = .floating
        #expect(try Data(contentsOf: file) != original)
        try? FileManager.default.removeItem(at: dir)
    }

    // MARK: 1.2

    /// The 1.1 menu bar options, frozen, to prove a 1.2 file still decodes
    /// on a 1.1 runtime.
    private struct MenuBarOptions11: Codable {
        var hideDockIcon: Bool
        var hotkey: Hotkey?
        var popoverSize: PopoverSize
    }

    private struct Settings11: Codable {
        var mode: String
        var menuBar: MenuBarOptions11
    }

    @Test func bakeOptionDefaultsOffAndRoundTrips() throws {
        let old = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"mode":"menuBar","menuBar":{"hideDockIcon":true}}"#.utf8))
        #expect(old.menuBar.bakeDockIcon == false)
        #expect(old.wantsBakedDockIcon == false)

        var settings = AppSettings()
        settings.mode = .menuBar
        settings.menuBar.bakeDockIcon = true
        let data = try JSONEncoder().encode(settings)
        #expect(try JSONDecoder().decode(AppSettings.self, from: data) == settings)

        let onOldRuntime = try JSONDecoder().decode(Settings11.self, from: data)
        #expect(onOldRuntime.mode == "menuBar")
        #expect(onOldRuntime.menuBar.hideDockIcon == true)
    }

    @Test func bakeOnlyAppliesToAHiddenMenuBarApp() {
        var settings = AppSettings()
        settings.menuBar.bakeDockIcon = true
        settings.mode = .window
        #expect(!settings.wantsBakedDockIcon)
        settings.mode = .floating
        #expect(!settings.wantsBakedDockIcon)
        settings.mode = .menuBar
        #expect(settings.wantsBakedDockIcon)
        settings.menuBar.hideDockIcon = false
        #expect(!settings.wantsBakedDockIcon)
    }

    @Test func oneShortcutForEveryMode() throws {
        // A 1.1 file keeps its shortcut, and it no longer depends on the mode.
        let data = Data(#"{"mode":"floating","menuBar":{"hotkey":{"keyCode":9,"modifiers":2048}}}"#.utf8)
        var settings = try JSONDecoder().decode(AppSettings.self, from: data)
        #expect(settings.hotkey == Hotkey(keyCode: 9, modifiers: Hotkey.Modifier.option))
        settings.hotkey = Hotkey(keyCode: 49, modifiers: Hotkey.Modifier.control)
        #expect(settings.menuBar.hotkey == settings.hotkey)
        settings.hotkey = nil
        #expect(settings.menuBar.hotkey == nil)
    }

    @Test func popoverDragMath() {
        let start = PopoverSize(width: 420, height: 640)
        // Centered: the corner keeps up with the pointer at twice the travel.
        #expect(start.dragged(dx: 40, dy: 30, centered: true) == PopoverSize(width: 500, height: 670))
        #expect(start.dragged(dx: 40, dy: 30, centered: false) == PopoverSize(width: 460, height: 670))
        // Never below the minimum, never past the screen.
        #expect(start.dragged(dx: -400, dy: -900, centered: true) == PopoverSize.minimum)
        #expect(start.dragged(dx: 900, dy: 900, centered: true, maxWidth: 1000, maxHeight: 800) == PopoverSize(width: 1000, height: 800))
        #expect(PopoverSize(width: 300.4, height: 250.6).clamped() == PopoverSize(width: 300, height: 251))
    }
}
