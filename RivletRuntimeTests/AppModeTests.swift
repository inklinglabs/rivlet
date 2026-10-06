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
}
