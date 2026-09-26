import Foundation
import Testing
@testable import RivletRuntime

@Suite struct BadgeTests {
    @Test func countsFromTitles() {
        #expect(BadgeController.count(inTitle: "Inbox (3) - user@example.com - Gmail") == 3)
        #expect(BadgeController.count(inTitle: "(12) Slack") == 12)
        #expect(BadgeController.count(inTitle: "4 \u{2022} Messages") == 4)
        #expect(BadgeController.count(inTitle: "Inbox - Gmail") == nil)
        #expect(BadgeController.count(inTitle: "Room 101 is booked") == nil)
    }
}

@Suite struct SettingsTests {
    @Test func decodesMissingKeysWithDefaults() throws {
        let data = Data("{\"showToolbar\": true}".utf8)
        let settings = try JSONDecoder().decode(AppSettings.self, from: data)
        #expect(settings.showToolbar == true)
        #expect(settings.badgeFromTitle == true)
        #expect(settings.allowedHosts.isEmpty)
        #expect(settings.userAgent == nil)
    }

    @Test @MainActor func storeRoundTrips() throws {
        let dir = FileManager.default.temporaryDirectory.appending(path: "rivlet-tests-\(UUID().uuidString)")
        let store = SettingsStore(bundleIdentifier: "com.inklinglabs.rivlet.app.test", directory: dir)
        store.settings.allowedHosts = ["a.com"]
        try store.writeUserScript(named: "one", source: "// x")
        try store.writeUserCSS("body{}")
        let again = SettingsStore(bundleIdentifier: "com.inklinglabs.rivlet.app.test", directory: dir)
        #expect(again.settings.allowedHosts == ["a.com"])
        #expect(again.userScriptFiles().count == 1)
        #expect(again.userCSS() == "body{}")
        try? FileManager.default.removeItem(at: dir)
    }
}

@Suite struct DownloadNamingTests {
    @Test func uniqueNames() throws {
        let dir = FileManager.default.temporaryDirectory.appending(path: "rivlet-dl-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data().write(to: dir.appending(path: "report.pdf"))
        #expect(DownloadManager.uniqueURL(in: dir, preferredName: "report.pdf").lastPathComponent == "report 2.pdf")
        #expect(DownloadManager.uniqueURL(in: dir, preferredName: "other.pdf").lastPathComponent == "other.pdf")
        try? FileManager.default.removeItem(at: dir)
    }
}
