import Foundation
import Testing
@testable import RivletRuntime

@Suite struct HotkeyTests {
    @Test func formatsModifiersAndSpecialKeys() {
        let space = Hotkey(keyCode: 49, modifiers: Hotkey.Modifier.command | Hotkey.Modifier.shift)
        #expect(HotkeyFormatter.string(for: space) == "\u{21E7}\u{2318}Space")
        let escape = Hotkey(keyCode: 53, modifiers: Hotkey.Modifier.control | Hotkey.Modifier.option)
        #expect(HotkeyFormatter.string(for: escape) == "\u{2303}\u{2325}\u{238B}")
        #expect(HotkeyFormatter.string(for: Hotkey(keyCode: 122, modifiers: Hotkey.Modifier.command)) == "\u{2318}F1")
    }

    @Test func reservedCombinationsAreRefused() {
        #expect(HotkeyFormatter.isReservedBySystem(Hotkey(keyCode: 49, modifiers: Hotkey.Modifier.command)))
        #expect(HotkeyFormatter.isReservedBySystem(Hotkey(keyCode: 48, modifiers: Hotkey.Modifier.command)))
        #expect(!HotkeyFormatter.isReservedBySystem(Hotkey(keyCode: 49, modifiers: Hotkey.Modifier.command | Hotkey.Modifier.shift)))
        #expect(!HotkeyFormatter.isReservedBySystem(Hotkey(keyCode: 49, modifiers: Hotkey.Modifier.control)))
    }
}
