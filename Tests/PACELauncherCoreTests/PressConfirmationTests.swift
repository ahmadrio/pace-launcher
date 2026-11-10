import Foundation
import Testing
@testable import PACELauncherCore

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

    @Test func `a second press counts only while its notice shows`() {
        var confirmation = PressConfirmation()
        #expect(confirmation.press("log-out", at: t0, stillShown: false) == false)
        #expect(confirmation.press("log-out", at: t0 + 1, stillShown: true) == true)
        #expect(confirmation.press("log-out", at: t0 + 2, stillShown: false) == false)
        // The notice went away (typing, moving): this press only arms again.
        #expect(confirmation.press("log-out", at: t0 + 2.5, stillShown: false) == false)
        #expect(confirmation.press("log-out", at: t0 + 3, stillShown: true) == true)
    }

    @Test func `the arm ends after three seconds`() {
        var confirmation = PressConfirmation()
        #expect(confirmation.press("a", at: t0) == false)
        #expect(confirmation.isArmed("a", at: t0 + 2.9))
        #expect(!confirmation.isArmed("b", at: t0 + 1))
        #expect(!confirmation.isArmed("a", at: t0 + 3))
        #expect(confirmation.press("a", at: t0 + 3.1, stillShown: true) == false)
    }

    @Test func `a clock that steps back ends the arm`() {
        var confirmation = PressConfirmation()
        #expect(confirmation.press("a", at: t0) == false)
        #expect(confirmation.isArmed("a", at: t0 - 30) == false)
        // An old press must not confirm just because the clock went back.
        #expect(confirmation.press("a", at: t0 - 30) == false)
        #expect(confirmation.press("a", at: t0 - 29) == true)
        #expect(PressConfirmation().window == 3)
    }
}
