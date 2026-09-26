import Foundation
import Sparkle

/// Thin wrapper around Sparkle's standard updater (ported from Palilogy).
///
/// The updater only starts when Info.plist carries both `SUFeedURL` and a
/// non-empty `SUPublicEDKey`; without them Sparkle refuses to run and would
/// show an error at launch, so such builds simply disable the feature.
@MainActor
final class UpdaterManager {

    static let shared = UpdaterManager()

    /// Info.plist has a feed and a key; drives whether the UI offers updates.
    let isConfigured: Bool
    /// The updater actually started.
    private let isActive: Bool
    private let controller: SPUStandardUpdaterController

    private init() {
        let info = Bundle.main.infoDictionary ?? [:]
        isConfigured = Self.isConfigured(info: info)
        // Never start the real updater inside the unit-test host ; those builds must not reach the network or offer updates.
        let underTest = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        isActive = isConfigured && !underTest
        controller = SPUStandardUpdaterController(
            startingUpdater: isActive, updaterDelegate: nil, userDriverDelegate: nil
        )
    }

    nonisolated static func isConfigured(info: [String: Any]) -> Bool {
        let feed = info["SUFeedURL"] as? String ?? ""
        let key = info["SUPublicEDKey"] as? String ?? ""
        return !feed.isEmpty && !key.isEmpty
    }

    var canCheckForUpdates: Bool {
        isActive && controller.updater.canCheckForUpdates
    }

    func checkForUpdates() {
        guard isActive else { return }
        controller.checkForUpdates(nil)
    }
}
