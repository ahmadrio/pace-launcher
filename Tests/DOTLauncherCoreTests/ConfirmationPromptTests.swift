import Foundation
import Testing
@testable import DOTLauncherCore

/// Time that only moves when a sleep wakes: a sleep wakes at the time it
/// was asked for, or now if the test already moved past it.
@MainActor
private final class FakeClock {
    var now = Date(timeIntervalSince1970: 1_800_000_000)

    func sleep(_ seconds: TimeInterval) async {
        let wake = now.addingTimeInterval(seconds)
        await Task.yield()
        now = max(now, wake)
    }
}

/// What the prompt's closures did.
@MainActor
private final class PromptUI {
    var shown = false
    var shows = 0
    var hides = 0
    var hiddenAt: Date?
}

@MainActor
struct ConfirmationPromptTests {
    private let clock = FakeClock()
    private let ui = PromptUI()
    private let prompt: ConfirmationPrompt

    init() {
        let clock = clock
        prompt = ConfirmationPrompt(now: { clock.now }, sleep: { await clock.sleep($0) })
    }

    private func press(_ id: String = "log-out") -> Bool {
        let ui = ui, clock = clock
        return prompt.press(
            id,
            isShown: { ui.shown },
            show: {
                ui.shown = true
                ui.shows += 1
            },
            hide: {
                ui.shown = false
                ui.hides += 1
                ui.hiddenAt = clock.now
            }
        )
    }

    @Test func `a stale press only shows the prompt again`() {
        #expect(press() == false)
        ui.shown = false // typing cleared it
        clock.now += 1
        #expect(press() == false)
        #expect(ui.shows == 2)
        #expect(ui.hides == 0)
    }

    @Test func `a confirmed press hides its prompt`() {
        #expect(press() == false)
        clock.now += 1
        #expect(press() == true)
        #expect(ui.hides == 1)
        #expect(!ui.shown)
    }

    @Test func `the prompt goes when the first press ends`() async {
        let start = clock.now
        #expect(press() == false)
        await prompt.pendingHide?.value
        #expect(ui.hides == 1)
        #expect(ui.hiddenAt.map { $0.timeIntervalSince(start) >= prompt.window } == true)
    }

    @Test func `a newer press keeps the prompt up`() async {
        let start = clock.now
        #expect(press() == false)
        let first = prompt.pendingHide
        await Task.yield() // the first hide starts sleeping at start
        ui.shown = false
        clock.now += 1
        #expect(press() == false) // arms again at start + 1
        await first?.value
        await prompt.pendingHide?.value
        #expect(ui.hides == 1)
        #expect(ui.hiddenAt.map { $0.timeIntervalSince(start) >= 4 } == true)
    }

    @Test func `another prompt is never hidden`() async {
        #expect(press() == false)
        ui.shown = false // another message replaced it
        await prompt.pendingHide?.value
        #expect(ui.hides == 0)
    }
}
