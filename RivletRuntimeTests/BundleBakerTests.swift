import Foundation
import Testing
@testable import RivletRuntime

@Suite struct BundleBakerTests {
    private func makeBundle() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appending(path: "rivlet-baker-\(UUID().uuidString)")
        let bundle = root.appending(path: "Baked.app")
        try FileManager.default.createDirectory(at: bundle.appending(path: "Contents/MacOS"), withIntermediateDirectories: true)
        let plist: [String: Any] = [
            "CFBundleIdentifier": "com.inklinglabs.rivlet.app.baked-000000", "CFBundleName": "Baked",
            "CFBundleExecutable": "RivletStub", "CFBundlePackageType": "APPL", "RivletApp": true,
        ]
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            .write(to: bundle.appending(path: "Contents/Info.plist"))
        // A real Mach-O, so codesign has something to embed a signature in.
        try FileManager.default.copyItem(at: URL(filePath: "/usr/bin/true"), to: bundle.appending(path: "Contents/MacOS/RivletStub"))
        return bundle
    }

    private func verify(_ bundle: URL) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/codesign")
        process.arguments = ["--verify", "--deep", "--strict", bundle.path]
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }

    @Test func bakesAndUnbakesAndStaysSigned() throws {
        let bundle = try makeBundle()
        defer { try? FileManager.default.removeItem(at: bundle.deletingLastPathComponent()) }

        #expect(!BundleBaker.isBaked(bundle))
        #expect(try BundleBaker.reconcile(bundle, wanted: false) == false)

        #expect(try BundleBaker.reconcile(bundle, wanted: true) == true)
        #expect(BundleBaker.isBaked(bundle))
        #expect(try verify(bundle) == 0)
        let info = NSDictionary(contentsOf: bundle.appending(path: "Contents/Info.plist")) as? [String: Any]
        #expect(info?["LSUIElement"] as? Bool == true)
        #expect(info?["RivletApp"] as? Bool == true)

        // Already right: nothing is rewritten.
        let before = try Data(contentsOf: bundle.appending(path: "Contents/MacOS/RivletStub"))
        #expect(try BundleBaker.reconcile(bundle, wanted: true) == false)
        #expect(try Data(contentsOf: bundle.appending(path: "Contents/MacOS/RivletStub")) == before)

        #expect(try BundleBaker.reconcile(bundle, wanted: false) == true)
        #expect(!BundleBaker.isBaked(bundle))
        #expect(try verify(bundle) == 0)
    }

    @Test func aBundleThatCannotBeWrittenIsLeftAlone() throws {
        let bundle = try makeBundle()
        let contents = bundle.appending(path: "Contents")
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: contents.path)
            try? FileManager.default.removeItem(at: bundle.deletingLastPathComponent())
        }
        let plist = try Data(contentsOf: contents.appending(path: "Info.plist"))
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: contents.path)
        #expect(throws: BundleBaker.Failure.self) {
            try BundleBaker.reconcile(bundle, wanted: true)
        }
        #expect(!BundleBaker.isBaked(bundle))
        #expect(try Data(contentsOf: contents.appending(path: "Info.plist")) == plist)
    }

    @Test func aMissingBundleIsUnreadable() {
        #expect(throws: BundleBaker.Failure.self) {
            try BundleBaker.reconcile(URL(filePath: "/nonexistent/Nope.app"), wanted: true)
        }
    }
}
