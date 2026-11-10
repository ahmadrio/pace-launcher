import Foundation

/// "Press again to confirm" whose prompt and first press end together: the
/// second press counts only while the prompt is still shown (typing, moving
/// or another message ends it), and the prompt goes away when the first
/// press stops counting.
@MainActor
public final class ConfirmationPrompt {
    private var confirmation: PressConfirmation
    private let now: @MainActor () -> Date
    private let sleep: @MainActor (TimeInterval) async -> Void
    /// Hides the latest prompt once its first press ends (awaited by tests).
    private(set) var pendingHide: Task<Void, Never>?

    /// `now` and `sleep` are the clock; tests pass a fake one.
    public init(
        window: TimeInterval = 3,
        now: @escaping @MainActor () -> Date = { Date.now },
        sleep: @escaping @MainActor (TimeInterval) async -> Void = { try? await Task.sleep(for: .seconds($0)) }
    ) {
        confirmation = PressConfirmation(window: window)
        self.now = now
        self.sleep = sleep
    }

    /// How long a first press counts, in seconds.
    public var window: TimeInterval { confirmation.window }

    /// True when this press confirms `id` (the prompt is then hidden).
    /// Otherwise the press arms `id` and `show` puts the prompt up; once the
    /// arm has ended, `hide` runs if `isShown` still says the prompt is up.
    public func press(
        _ id: String,
        isShown: @escaping @MainActor () -> Bool,
        show: @MainActor () -> Void,
        hide: @escaping @MainActor () -> Void
    ) -> Bool {
        if confirmation.press(id, at: now(), stillShown: isShown()) {
            if isShown() { hide() }
            return true
        }
        show()
        let window = window, sleep = sleep, now = now
        pendingHide = Task { [weak self] in
            await sleep(window + 0.1)
            // A newer press of the same id keeps the prompt until it ends too.
            while let self, self.confirmation.isArmed(id, at: now()) {
                await sleep(0.2)
            }
            if isShown() { hide() }
        }
        return false
    }

    public func reset() {
        confirmation.reset()
    }
}
