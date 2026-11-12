import Foundation
import CoreServices

/// The one place a generated app's bundle is edited after it is made.
///
/// Everything a user can change lives in `settings.json`, with a single
/// exception: an app that must stay out of the Dock even while it launches
/// needs `LSUIElement` in its `Info.plist` before the process starts, and
/// nothing at runtime can do that. The baker writes or removes that key to
/// match the settings and signs the bundle again.
public enum BundleBaker {
    public enum Failure: LocalizedError {
        case unreadable
        case notWritable(String)
        case signingFailed(String)

        public var errorDescription: String? {
            switch self {
            case .unreadable:
                return "The app\u{2019}s Info.plist could not be read."
            case .notWritable(let detail):
                return "The app could not be changed. \(detail)"
            case .signingFailed(let detail):
                return "The app could not be signed again. \(detail)"
            }
        }
    }

    static let key = "LSUIElement"

    /// Whether the bundle is currently set to stay out of the Dock.
    public static func isBaked(_ bundle: URL) -> Bool {
        guard let info = try? readInfo(bundle) else { return false }
        return info[key] as? Bool == true
    }

    /// Makes the bundle match `wanted`. Returns true when it had to change
    /// something. Does nothing, and touches nothing, when it already matches.
    @discardableResult
    public static func reconcile(_ bundle: URL, wanted: Bool) throws -> Bool {
        var info = try readInfo(bundle)
        guard (info[key] as? Bool == true) != wanted else { return false }
        let plistURL = bundle.appending(path: "Contents/Info.plist")
        let original = try Data(contentsOf: plistURL)
        if wanted { info[key] = true } else { info[key] = nil }
        do {
            let out = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
            try out.write(to: plistURL, options: .atomic)
        } catch {
            throw Failure.notWritable(error.localizedDescription)
        }
        do {
            try sign(bundle)
        } catch {
            // Put the old plist back and sign that, so a failed bake never
            // leaves a bundle whose signature does not match its contents.
            try? original.write(to: plistURL, options: .atomic)
            try? sign(bundle)
            throw error
        }
        // LaunchServices caches Info.plist by bundle date.
        try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: bundle.path)
        LSRegisterURL(bundle as CFURL, true)
        return true
    }

    private static func readInfo(_ bundle: URL) throws -> [String: Any] {
        let plistURL = bundle.appending(path: "Contents/Info.plist")
        guard let data = try? Data(contentsOf: plistURL),
              let info = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
        else { throw Failure.unreadable }
        return info
    }

    private static func sign(_ bundle: URL) throws {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/codesign")
        process.arguments = ["--force", "--deep", "--sign", "-", bundle.path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do { try process.run() } catch { throw Failure.signingFailed(error.localizedDescription) }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw Failure.signingFailed(String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}
