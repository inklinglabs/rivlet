import Foundation
import Testing
@testable import Rivlet

@Suite struct AppBundleWriterTests {
    @Test func slugs() {
        #expect(AppBundleWriter.slug("Gmail") == "gmail")
        #expect(AppBundleWriter.slug("Captain's Log 2") == "captain-s-log-2")
        #expect(AppBundleWriter.slug("  Über Café ") == "uber-cafe")
        #expect(AppBundleWriter.slug("!!!") == "app")
        #expect(AppBundleWriter.bundleIdentifier(for: "Gmail", random: 0xABCDEF) == "com.inklinglabs.rivlet.app.gmail-abcdef")
    }

    @Test func rewritesPlistAndBuildsBundle() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "rivlet-writer-\(UUID().uuidString)")
        let template = root.appending(path: "Template.app")
        try FileManager.default.createDirectory(at: template.appending(path: "Contents/MacOS"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: template.appending(path: "Contents/Resources"), withIntermediateDirectories: true)
        let plist: [String: Any] = ["CFBundleIdentifier": "x", "CFBundleName": "x", "CFBundleExecutable": "RivletStub", "CFBundlePackageType": "APPL"]
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            .write(to: template.appending(path: "Contents/Info.plist"))
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: template.appending(path: "Contents/MacOS/RivletStub"))
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: template.appending(path: "Contents/MacOS/RivletStub").path)

        let request = AppBundleRequest(name: "Test Mail", url: URL(string: "https://mail.example.com/")!, iconPNG: nil, destinationDirectory: root.appending(path: "out"))
        let app = try await AppBundleWriter.build(request, template: template)
        #expect(app.bundlePath.hasSuffix("/out/Test Mail.app"))
        #expect(app.bundleIdentifier.hasPrefix("com.inklinglabs.rivlet.app.test-mail-"))

        let info = NSDictionary(contentsOf: app.bundleURL.appending(path: "Contents/Info.plist")) as? [String: Any]
        #expect(info?["CFBundleIdentifier"] as? String == app.bundleIdentifier)
        #expect(info?["RivletURL"] as? String == "https://mail.example.com/")
        #expect(info?["RivletApp"] as? Bool == true)
        #expect(info?["CFBundleDisplayName"] as? String == "Test Mail")

        await #expect(throws: AppBundleError.self) {
            _ = try await AppBundleWriter.build(request, template: template)
        }
        try? FileManager.default.removeItem(at: root)
        try? FileManager.default.removeItem(at: RivletRuntimePaths.appDirectory(for: app.bundleIdentifier))
    }
}

import RivletRuntime
private typealias RivletRuntimePaths = RivletPaths
