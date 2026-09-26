import Foundation
import Testing
@testable import RivletRuntime

@Suite struct AppIdentityTests {
    @Test func rejectsBundleWithoutMarker() {
        #expect(AppIdentity(bundle: .main) == nil)
    }
}
