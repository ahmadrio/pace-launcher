import DOTLauncherCore
import Foundation

/// "Press again to confirm" whose prompt and first press end together: the
/// second press counts only while the prompt is still shown (typing, moving
/// or another message ends it), and the prompt goes away when the first
/// press stops counting.
final class ConfirmationPrompt {
    private var confirmation = PressConfirmation()

    /// How long a first press counts, in seconds.
    var window: TimeInterval { confirmation.window }

    /// True when this press confirms `id` (the prompt is then hidden).
    /// Otherwise the press arms `id` and `show` puts the prompt up; once the
    /// arm has ended, `hide` runs if `isShown` still says the prompt is up.
    func press(_ id: String, isShown: @escaping () -> Bool, show: () -> Void, hide: @escaping () -> Void) -> Bool {
        if confirmation.press(id, at: .now, stillShown: isShown()) {
            if isShown() { hide() }
            return true
        }
        show()
        let window = window
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(window + 0.1))
            // A newer press of the same id keeps the prompt until it ends too.
            while let self, self.confirmation.isArmed(id, at: .now) {
                try? await Task.sleep(for: .milliseconds(200))
            }
            if isShown() { hide() }
        }
        return false
    }

    func reset() {
        confirmation.reset()
    }
}
