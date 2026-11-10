import Foundation
import Testing
@testable import PACELauncherCore

/// Time that moves only when a test sets it; sleepers wake once it passes
/// their time.
@MainActor
private final class FakeClock {
    private(set) var now = Date(timeIntervalSince1970: 1_800_000_000)
    private var sleepers: [(until: Date, wake: UnsafeContinuation<Void, Never>)] = []

    func sleep(until date: Date) async {
        guard date > now else { return }
        await withUnsafeContinuation { sleepers.append((date, $0)) }
    }

    /// Moves the clock and wakes every sleeper that is due, then lets them run.
    func set(_ date: Date) async {
        now = date
        let due = sleepers.filter { $0.until <= date }
        sleepers.removeAll { $0.until <= date }
        for sleeper in due { sleeper.wake.resume() }
        for _ in 0..<50 { await Task.yield() }
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
        prompt = ConfirmationPrompt(now: { clock.now }, sleep: { await clock.sleep(until: $0) })
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

    @Test func `a stale press only shows the prompt again`() async {
        let start = clock.now
        #expect(press() == false)
        ui.shown = false // typing cleared it
        await clock.set(start + 1)
        #expect(press() == false)
        #expect(ui.shows == 2)
        #expect(ui.hides == 0)
    }

    @Test func `a confirmed press hides its prompt`() async {
        let start = clock.now
        #expect(press() == false)
        await clock.set(start + 1)
        #expect(press() == true)
        #expect(ui.hides == 1)
        #expect(!ui.shown)
    }

    @Test func `the prompt goes when the first press ends`() async {
        let start = clock.now
        #expect(press() == false)
        await clock.set(start + 2.9)
        #expect(ui.hides == 0)
        await clock.set(start + 3.2)
        await prompt.pendingHide?.value
        #expect(ui.hides == 1)
        #expect(ui.hiddenAt == start + 3.2)
    }

    @Test func `a newer press keeps the prompt up`() async {
        let start = clock.now
        #expect(press() == false)
        let first = prompt.pendingHide
        ui.shown = false // typing cleared it
        await clock.set(start + 1)
        #expect(press() == false) // arms again at start + 1
        await clock.set(start + 3.2) // the first press's check
        #expect(ui.hides == 0, "the newer press still counts")
        await clock.set(start + 4.2)
        await first?.value
        await prompt.pendingHide?.value
        #expect(ui.hides == 1, "hides \(ui.hides), shows \(ui.shows)")
        #expect(ui.hiddenAt == start + 4.2)
    }

    @Test func `another prompt is never hidden`() async {
        let start = clock.now
        #expect(press() == false)
        ui.shown = false // another message replaced it
        await clock.set(start + 3.2)
        await prompt.pendingHide?.value
        #expect(ui.hides == 0)
    }
}
