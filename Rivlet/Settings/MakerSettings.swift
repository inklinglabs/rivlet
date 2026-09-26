import AppKit
import RivletRuntime

enum AppearanceOption: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

/// UserDefaults-backed settings for the maker app itself.
enum MakerSettings {
    static let appearanceKey = "appearance"
    static let appsFolderKey = "appsFolder"

    static var appearance: AppearanceOption {
        AppearanceOption(rawValue: UserDefaults.standard.string(forKey: appearanceKey) ?? "") ?? .system
    }

    @MainActor
    static func setAppearance(_ value: AppearanceOption) {
        UserDefaults.standard.set(value.rawValue, forKey: appearanceKey)
        applyAppearance()
    }

    static var appsFolder: URL {
        get {
            if let path = UserDefaults.standard.string(forKey: appsFolderKey), !path.isEmpty {
                return URL(filePath: path, directoryHint: .isDirectory)
            }
            return RivletPaths.userApplications
        }
        set { UserDefaults.standard.set(newValue.path, forKey: appsFolderKey) }
    }

    @MainActor
    static func applyAppearance() {
        switch appearance {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}
