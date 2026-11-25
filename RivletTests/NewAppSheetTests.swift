import Testing
@testable import Rivlet

@Suite struct NewAppSheetTests {
    @Test func anEmptyNameIsFilledIn() {
        #expect(NewAppSheet.shouldReplaceName(current: "", lastSuggested: ""))
        #expect(NewAppSheet.shouldReplaceName(current: "  ", lastSuggested: "Gmail"))
    }

    @Test func aNameFromAnEarlierLookupFollowsTheNewAddress() {
        #expect(NewAppSheet.shouldReplaceName(current: "Gmail", lastSuggested: "Gmail"))
    }

    @Test func aNameTheUserTypedIsKept() {
        #expect(!NewAppSheet.shouldReplaceName(current: "Work Mail", lastSuggested: "Gmail"))
        #expect(!NewAppSheet.shouldReplaceName(current: "Work Mail", lastSuggested: ""))
    }
}
