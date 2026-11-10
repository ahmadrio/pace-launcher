import DOTLauncherCore
import Foundation
import Observation

/// Retention and Clear History for the clipboard history: prunes old
/// unpinned clips at launch, every hour, and when the setting changes.
@Observable
final class ClipboardMaintenance {
    /// The last Clear History message, shown under the button.
    private(set) var status: String?

    @ObservationIgnored private let store: ClipboardStore?
    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private var confirmation = PressConfirmation()
    @ObservationIgnored private var timer: Task<Void, Never>?
    /// Called after clips were removed, to refresh a visible list.
    @ObservationIgnored var onChange: (() -> Void)?

    init(store: ClipboardStore?, settings: SettingsStore) {
        self.store = store
        self.settings = settings
    }

    /// Prunes now and then every hour; also removes image files no clip
    /// refers to (after a crash or a restored backup).
    func start() {
        if let store {
            Task {
                let removed = (try? await store.removeOrphanImages()) ?? 0
                if removed > 0 { Log.clipboard.notice("removed \(removed) orphaned clipboard image files") }
            }
        }
        prune()
        timer?.cancel()
        timer = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3600))
                self?.prune()
            }
        }
    }

    /// Removes unpinned clips older than the chosen retention.
    func prune() {
        guard let store, let cutoff = settings.data.clipboardRetention.cutoff(now: .now) else { return }
        Task {
            do {
                let removed = try await store.prune(lastUsedBefore: cutoff)
                guard removed > 0 else { return }
                Log.clipboard.notice("removed \(removed) clips older than the retention limit")
                onChange?()
            } catch {
                Log.clipboard.error("clipboard pruning failed: \(String(describing: error), privacy: .public)")
            }
        }
    }

    /// Clear History: the first press arms, a second within 3 s clears.
    func pressClear() {
        guard let store else { return }
        guard confirmation.press("clear", at: .now) else {
            status = "Press again to delete every unpinned clip."
            return
        }
        Task {
            do {
                let removed = try await store.clearUnpinned()
                status = removed == 1 ? "Deleted 1 clip." : "Deleted \(removed) clips."
                Log.clipboard.notice("cleared \(removed) unpinned clips")
                onChange?()
            } catch {
                status = "Could not clear the history."
                Log.clipboard.error("clearing the clipboard failed: \(String(describing: error), privacy: .public)")
            }
        }
    }
}
