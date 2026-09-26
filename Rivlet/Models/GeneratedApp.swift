import Foundation

/// One app Rivlet made. The registry is a convenience; the bundle on disk
/// is the truth and entries whose bundle is gone are dropped on load.
struct GeneratedApp: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var name: String
    var url: URL
    var bundleIdentifier: String
    var bundlePath: String
    var createdAt: Date

    var bundleURL: URL { URL(filePath: bundlePath) }
    var exists: Bool { FileManager.default.fileExists(atPath: bundlePath) }
}
