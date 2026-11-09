import Foundation
import Testing
@testable import DOTLauncherCore

struct PressConfirmationTests {
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func `first press only arms`() {
        var confirmation = PressConfirmation()
        #expect(confirmation.press("a", at: t0) == false)
        #expect(confirmation.armedID == "a")
    }

    @Test func `second press within the window confirms`() {
        var confirmation = PressConfirmation()
        _ = confirmation.press("a", at: t0)
        #expect(confirmation.press("a", at: t0.addingTimeInterval(2)) == true)
        #expect(confirmation.armedID == nil)
    }

    @Test func `second press after the window re-arms instead`() {
        var confirmation = PressConfirmation()
        _ = confirmation.press("a", at: t0)
        #expect(confirmation.press("a", at: t0.addingTimeInterval(3.5)) == false)
        #expect(confirmation.armedID == "a")
    }

    @Test func `pressing another item re-arms for that item`() {
        var confirmation = PressConfirmation()
        _ = confirmation.press("a", at: t0)
        #expect(confirmation.press("b", at: t0.addingTimeInterval(1)) == false)
        #expect(confirmation.armedID == "b")
    }
}
