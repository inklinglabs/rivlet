import AppKit
import RivletRuntime

struct AppBundleRequest: Sendable {
    var name: String
    var url: URL
    var iconPNG: Data?
    var destinationDirectory: URL
}

enum AppBundleError: LocalizedError {
    case templateMissing
    case alreadyExists(URL)
    case signingFailed(String)
    case iconFailed(String)

    var errorDescription: String? {
        switch self {
        case .templateMissing:
            return "Rivlet's app template is missing. Reinstall Rivlet."
        case .alreadyExists(let url):
            return "An app named \(url.deletingPathExtension().lastPathComponent) already exists in that folder."
        case .signingFailed(let output):
            return "The app could not be signed. \(output)"
        case .iconFailed(let output):
            return "The icon could not be written. \(output)"
        }
    }
}

/// Turns the template into a real app: copy, rewrite Info.plist, write the
/// icon, sign ad hoc, seed settings.
enum AppBundleWriter {
    static var templateURL: URL {
        Bundle.main.bundleURL.appending(path: "Contents/Helpers/RivletTemplate.app")
    }

    static func build(_ request: AppBundleRequest, template: URL = templateURL) async throws -> GeneratedApp {
        guard FileManager.default.fileExists(atPath: template.path) else { throw AppBundleError.templateMissing }
        let cleanName = Self.fileSafe(request.name)
        let destination = request.destinationDirectory.appending(path: "\(cleanName).app")
        if FileManager.default.fileExists(atPath: destination.path) { throw AppBundleError.alreadyExists(destination) }
        try RivletPaths.ensureDirectory(request.destinationDirectory)

        let bundleIdentifier = Self.bundleIdentifier(for: request.name)
        try FileManager.default.copyItem(at: template, to: destination)
        do {
            try Self.rewriteInfoPlist(at: destination, name: request.name, url: request.url, bundleIdentifier: bundleIdentifier)
            if let png = request.iconPNG {
                try await IconRenderer.writeICNS(png: png, to: destination.appending(path: "Contents/Resources/AppIcon.icns"))
            }
            try await Self.sign(destination)
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw error
        }

        await MainActor.run {
            let store = SettingsStore(bundleIdentifier: bundleIdentifier)
            store.settings.allowedHosts = NavigationPolicy.seededAllowedHosts(for: request.url)
            store.save()
        }
        return GeneratedApp(id: UUID(), name: request.name, url: request.url, bundleIdentifier: bundleIdentifier, bundlePath: destination.path, createdAt: Date())
    }

    static func rewriteInfoPlist(at bundle: URL, name: String, url: URL, bundleIdentifier: String) throws {
        let plistURL = bundle.appending(path: "Contents/Info.plist")
        let data = try Data(contentsOf: plistURL)
        var format = PropertyListSerialization.PropertyListFormat.xml
        guard var info = try PropertyListSerialization.propertyList(from: data, options: [], format: &format) as? [String: Any] else {
            throw CocoaError(.propertyListReadCorrupt)
        }
        info["CFBundleIdentifier"] = bundleIdentifier
        info["CFBundleName"] = String(name.prefix(15))
        info["CFBundleDisplayName"] = name
        info[AppIdentity.InfoKey.rivletURL] = url.absoluteString
        info[AppIdentity.InfoKey.rivletApp] = true
        info["NSHumanReadableCopyright"] = "\(name), made with Rivlet"
        let out = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        try out.write(to: plistURL, options: .atomic)
    }

    static func sign(_ bundle: URL) async throws {
        let result = try await Shell.run("/usr/bin/codesign", ["--force", "--deep", "--sign", "-", bundle.path])
        guard result.status == 0 else { throw AppBundleError.signingFailed(result.output) }
    }

    /// `com.inklinglabs.rivlet.app.<slug>-<6 hex>`
    static func bundleIdentifier(for name: String, random: UInt32 = UInt32.random(in: 0...0xFFFFFF)) -> String {
        RivletPaths.generatedBundlePrefix + slug(name) + "-" + String(format: "%06x", random)
    }

    static func slug(_ name: String) -> String {
        let lowered = name.lowercased().folding(options: .diacriticInsensitive, locale: nil)
        var out = ""
        var lastDash = true
        for scalar in lowered.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar), scalar.isASCII {
                out.unicodeScalars.append(scalar)
                lastDash = false
            } else if !lastDash {
                out.append("-")
                lastDash = true
            }
        }
        while out.hasSuffix("-") { out.removeLast() }
        if out.isEmpty { out = "app" }
        return String(out.prefix(32))
    }

    static func fileSafe(_ name: String) -> String {
        let cleaned = name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Rivlet App" : cleaned
    }
}

enum Shell {
    struct Result: Sendable { let status: Int32; let output: String }

    static func run(_ executable: String, _ arguments: [String]) async throws -> Result {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(filePath: executable)
            process.arguments = arguments
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            process.terminationHandler = { proc in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(returning: Result(status: proc.terminationStatus, output: String(decoding: data, as: UTF8.self)))
            }
            do { try process.run() } catch { continuation.resume(throwing: error) }
        }
    }
}
