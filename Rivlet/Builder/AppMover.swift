import AppKit
import RivletRuntime

enum AppMoverError: LocalizedError, Equatable {
    case alreadyExists(String)
    case stillRunning(String)
    case cancelled
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .alreadyExists(let name):
            return "An app named \(name) is already in that folder. Nothing was moved."
        case .stillRunning(let name):
            return "\(name) is still running. Quit it and try again."
        case .cancelled:
            return nil
        case .failed(let detail):
            return "The app could not be moved. \(detail)"
        }
    }
}

/// Moves a generated app's bundle to another folder. An admin user can
/// write to /Applications directly; anyone else gets the system password
/// dialog, once, for this one move.
enum AppMover {
    /// Returns the bundle's new URL.
    @MainActor
    static func move(_ bundle: URL, bundleIdentifier: String, to directory: URL) async throws -> URL {
        let destination = directory.appending(path: bundle.lastPathComponent)
        let name = bundle.deletingPathExtension().lastPathComponent
        guard bundle.standardizedFileURL != destination.standardizedFileURL else { return bundle }
        if FileManager.default.fileExists(atPath: destination.path) { throw AppMoverError.alreadyExists(name) }
        try await quit(bundleIdentifier: bundleIdentifier, name: name)

        do {
            try RivletPaths.ensureDirectory(directory)
            try FileManager.default.moveItem(at: bundle, to: destination)
        } catch let error as CocoaError where Self.isPermissionError(error) {
            try await moveAsAdmin(bundle, to: destination)
        } catch {
            throw AppMoverError.failed(error.localizedDescription)
        }
        // A new path is a new app as far as the icon cache and
        // LaunchServices go.
        try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: destination.path)
        return destination
    }

    static func isPermissionError(_ error: CocoaError) -> Bool {
        if error.code == .fileWriteNoPermission || error.code == .fileReadNoPermission { return true }
        if let posix = error.underlying as? POSIXError { return posix.code == .EACCES || posix.code == .EPERM }
        return false
    }

    /// The shell line the admin fallback runs. Moves the bundle, then hands
    /// it back to the user, so later edits and Move to Trash need no
    /// password. Paths are single quoted for the shell.
    static func adminCommand(from source: URL, to destination: URL, user: String) -> String {
        "/bin/mkdir -p \(quote(destination.deletingLastPathComponent().path)) && "
            + "/bin/mv -n \(quote(source.path)) \(quote(destination.path)) && "
            + "/usr/sbin/chown -R \(quote(user)) \(quote(destination.path))"
    }

    static func quote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    @MainActor
    private static func quit(bundleIdentifier: String, name: String) async throws {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
        guard !running.isEmpty else { return }
        running.forEach { $0.terminate() }
        for _ in 0..<50 {
            if running.allSatisfy(\.isTerminated) { return }
            try? await Task.sleep(for: .milliseconds(100))
        }
        throw AppMoverError.stillRunning(name)
    }

    @MainActor
    private static func moveAsAdmin(_ bundle: URL, to destination: URL) async throws {
        let command = adminCommand(from: bundle, to: destination, user: NSUserName())
        let escaped = command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let source = "do shell script \"\(escaped)\" with prompt \"Rivlet needs an administrator to move this app to \(destination.deletingLastPathComponent().lastPathComponent).\" with administrator privileges"
        var errorInfo: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&errorInfo)
        if let errorInfo {
            // -128 is "User canceled."
            if (errorInfo[NSAppleScript.errorNumber] as? Int) == -128 { throw AppMoverError.cancelled }
            throw AppMoverError.failed((errorInfo[NSAppleScript.errorMessage] as? String) ?? "The administrator step failed.")
        }
        guard FileManager.default.fileExists(atPath: destination.path) else {
            throw AppMoverError.failed("The app is not in the new folder.")
        }
    }
}
