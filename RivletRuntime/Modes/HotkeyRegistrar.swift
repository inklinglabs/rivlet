import AppKit
import Carbon

/// Registers global hotkeys through Carbon's `RegisterEventHotKey`, which
/// needs no Accessibility or Input Monitoring permission. One registrar per
/// process; each registration gets a token to unregister with.
@MainActor
final class HotkeyRegistrar {
    static let shared = HotkeyRegistrar()

    final class Token {
        fileprivate let id: UInt32
        fileprivate let ref: EventHotKeyRef
        fileprivate init(id: UInt32, ref: EventHotKeyRef) { self.id = id; self.ref = ref }
    }

    enum Failure: Error, Equatable {
        /// Another running app already owns this combination.
        case alreadyUsed
        case failed(OSStatus)
    }

    private static let signature: OSType = 0x52564C54 // "RVLT"
    private var handlers: [UInt32: () -> Void] = [:]
    private var nextID: UInt32 = 1
    private var eventHandler: EventHandlerRef?

    private init() {}

    func register(_ hotkey: Hotkey, handler: @escaping () -> Void) throws(Failure) -> Token {
        installHandlerIfNeeded()
        let id = nextID
        nextID += 1
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            hotkey.keyCode, hotkey.modifiers,
            EventHotKeyID(signature: Self.signature, id: id),
            GetApplicationEventTarget(), 0, &ref
        )
        guard status == noErr, let ref else {
            throw status == OSStatus(eventHotKeyExistsErr) ? .alreadyUsed : .failed(status)
        }
        handlers[id] = handler
        return Token(id: id, ref: ref)
    }

    func unregister(_ token: Token) {
        UnregisterEventHotKey(token.ref)
        handlers[token.id] = nil
    }

    private func installHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var hotkeyID = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotkeyID)
            guard status == noErr else { return status }
            MainActor.assumeIsolated {
                HotkeyRegistrar.shared.handlers[hotkeyID.id]?()
            }
            return noErr
        }, 1, &spec, nil, &eventHandler)
    }
}

/// Turns a hotkey into the string a menu would show, and knows which
/// combinations the system owns.
enum HotkeyFormatter {
    nonisolated static func string(for hotkey: Hotkey) -> String {
        var out = ""
        if hotkey.modifiers & Hotkey.Modifier.control != 0 { out += "\u{2303}" }
        if hotkey.modifiers & Hotkey.Modifier.option != 0 { out += "\u{2325}" }
        if hotkey.modifiers & Hotkey.Modifier.shift != 0 { out += "\u{21E7}" }
        if hotkey.modifiers & Hotkey.Modifier.command != 0 { out += "\u{2318}" }
        return out + keyName(for: hotkey.keyCode)
    }

    nonisolated static func keyName(for keyCode: UInt32) -> String {
        if let special = specialKeys[keyCode] { return special }
        return layoutCharacter(for: keyCode)?.uppercased() ?? "Key \(keyCode)"
    }

    /// Combinations macOS itself answers to. Recording one would silently
    /// lose to the system, so the recorder refuses them.
    nonisolated static func isReservedBySystem(_ hotkey: Hotkey) -> Bool {
        let cmd = Hotkey.Modifier.command
        let reserved: [Hotkey] = [
            Hotkey(keyCode: 49, modifiers: cmd),                           // Cmd-Space, Spotlight
            Hotkey(keyCode: 49, modifiers: cmd | Hotkey.Modifier.option),  // Cmd-Option-Space
            Hotkey(keyCode: 48, modifiers: cmd),                           // Cmd-Tab
            Hotkey(keyCode: 48, modifiers: cmd | Hotkey.Modifier.shift),
            Hotkey(keyCode: 12, modifiers: cmd),                           // Cmd-Q
            Hotkey(keyCode: 13, modifiers: cmd),                           // Cmd-W
            Hotkey(keyCode: 4, modifiers: cmd),                            // Cmd-H
            Hotkey(keyCode: 20, modifiers: cmd | Hotkey.Modifier.shift),   // Cmd-Shift-3
            Hotkey(keyCode: 21, modifiers: cmd | Hotkey.Modifier.shift),   // Cmd-Shift-4
            Hotkey(keyCode: 23, modifiers: cmd | Hotkey.Modifier.shift),   // Cmd-Shift-5
        ]
        return reserved.contains(hotkey)
    }

    nonisolated static let specialKeys: [UInt32: String] = [
        36: "\u{21A9}", 48: "\u{21E5}", 49: "Space", 51: "\u{232B}", 53: "\u{238B}",
        71: "Clear", 76: "\u{2305}", 96: "F5", 97: "F6", 98: "F7", 99: "F3",
        100: "F8", 101: "F9", 103: "F11", 105: "F13", 107: "F14", 109: "F10",
        111: "F12", 113: "F15", 114: "Help", 115: "\u{2196}", 116: "\u{21DE}",
        117: "\u{2326}", 118: "F4", 119: "\u{2198}", 120: "F2", 121: "\u{21DF}",
        122: "F1", 123: "\u{2190}", 124: "\u{2192}", 125: "\u{2193}", 126: "\u{2191}",
    ]

    nonisolated private static func layoutCharacter(for keyCode: UInt32) -> String? {
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(layoutData).takeUnretainedValue() as Data
        var deadKeys: UInt32 = 0
        var length = 0
        var chars = [UniChar](repeating: 0, count: 4)
        let status = data.withUnsafeBytes { bytes -> OSStatus in
            guard let layout = bytes.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return -1 }
            return UCKeyTranslate(layout, UInt16(keyCode), UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
                                  OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeys, chars.count, &length, &chars)
        }
        guard status == noErr, length > 0 else { return nil }
        return String(utf16CodeUnits: chars, count: length)
    }
}

extension Hotkey {
    /// Builds a hotkey from a key event, mapping AppKit modifier flags to
    /// Carbon's. Returns nil for a bare key with no modifier.
    nonisolated static func from(event: NSEvent) -> Hotkey? {
        var modifiers: UInt32 = 0
        let flags = event.modifierFlags
        if flags.contains(.command) { modifiers |= Modifier.command }
        if flags.contains(.shift) { modifiers |= Modifier.shift }
        if flags.contains(.option) { modifiers |= Modifier.option }
        if flags.contains(.control) { modifiers |= Modifier.control }
        let hotkey = Hotkey(keyCode: UInt32(event.keyCode), modifiers: modifiers)
        return hotkey.hasModifier ? hotkey : nil
    }
}
