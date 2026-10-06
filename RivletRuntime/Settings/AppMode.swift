import Foundation

/// How a generated app presents itself. Stored in `settings.json` next to
/// everything else the user can change, never in the bundle, so switching
/// modes never touches the bundle or its signature.
public enum AppMode: String, Codable, Sendable, CaseIterable, Identifiable {
    /// A normal window. What every v1 app does.
    case window
    /// A status item whose popover holds the page.
    case menuBar
    /// A window that stays above normal windows.
    case floating

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .window: return "Window"
        case .menuBar: return "Menu bar"
        case .floating: return "Floating"
        }
    }
}

/// A global keyboard shortcut in Carbon terms, which is what
/// `RegisterEventHotKey` takes. `modifiers` is a Carbon modifier mask
/// (`cmdKey`, `optionKey`, `controlKey`, `shiftKey`), not an NSEvent one.
public struct Hotkey: Codable, Sendable, Equatable, Hashable {
    public var keyCode: UInt32
    public var modifiers: UInt32

    public init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// Carbon modifier bits, spelled out so the model has no Carbon import.
    public enum Modifier {
        public static let command: UInt32 = 1 << 8
        public static let shift: UInt32 = 1 << 9
        public static let option: UInt32 = 1 << 11
        public static let control: UInt32 = 1 << 12
        public static let all: UInt32 = command | shift | option | control
    }

    /// A hotkey must carry at least one modifier so a bare letter can never
    /// be captured system wide.
    public var hasModifier: Bool { modifiers & Modifier.all != 0 }
}

public struct PopoverSize: Codable, Sendable, Equatable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }

    public static let `default` = PopoverSize(width: 420, height: 640)
    public static let minimum = PopoverSize(width: 280, height: 200)
}

public struct MenuBarOptions: Codable, Sendable, Equatable {
    public var hideDockIcon = true
    public var hotkey: Hotkey?
    public var popoverSize = PopoverSize.default

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case hideDockIcon, hotkey, popoverSize
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = MenuBarOptions()
        hideDockIcon = try c.decodeIfPresent(Bool.self, forKey: .hideDockIcon) ?? d.hideDockIcon
        hotkey = try c.decodeIfPresent(Hotkey.self, forKey: .hotkey)
        popoverSize = try c.decodeIfPresent(PopoverSize.self, forKey: .popoverSize) ?? d.popoverSize
    }
}

public struct FloatingOptions: Codable, Sendable, Equatable {
    public var allSpaces = false

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case allSpaces
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        allSpaces = try c.decodeIfPresent(Bool.self, forKey: .allSpaces) ?? FloatingOptions().allSpaces
    }
}
