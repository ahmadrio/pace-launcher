import Observation
import PACELauncherCore

/// The permission rows of the welcome window, read again every second
/// while it is open, so a switch flipped in System Settings shows at once.
@Observable
final class PermissionStatus {
    private(set) var rows: [PermissionRow] = []

    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let autoExpand: AutoExpandController
    @ObservationIgnored private let clipboardAccess: () -> PasteboardMonitor.Access?
    /// Auto-expand was asked to start after Input Monitoring was granted.
    @ObservationIgnored private var retriedAutoExpand = false
    @ObservationIgnored private var watch: Task<Void, Never>?

    init(settings: SettingsStore, autoExpand: AutoExpandController, clipboardAccess: @escaping () -> PasteboardMonitor.Access?) {
        self.settings = settings
        self.autoExpand = autoExpand
        self.clipboardAccess = clipboardAccess
    }

    func startWatching() {
        refresh()
        guard watch == nil else { return }
        watch = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                self?.refresh()
            }
        }
    }

    func stopWatching() {
        watch?.cancel()
        watch = nil
    }

    func refresh() {
        var facts = currentFacts()
        if PermissionChecklist.shouldRetryAutoExpand(facts) {
            // Once per grant: starting the keyboard tap may work without a relaunch.
            if !retriedAutoExpand {
                retriedAutoExpand = true
                autoExpand.refresh()
                facts = currentFacts()
            }
        } else {
            retriedAutoExpand = false
        }
        let fresh = PermissionChecklist.rows(facts)
        if fresh != rows { rows = fresh }
    }

    private func currentFacts() -> PermissionFacts {
        let clipboard: ClipboardPermission? = switch clipboardAccess() {
        case .recording?: .allowed
        case .needsPermission?: .asksEachTime
        case .denied?: .denied
        case nil: nil
        }
        return PermissionFacts(
            accessibility: AccessibilityPermission.isGranted,
            inputMonitoring: KeystrokeMonitor.hasPermission,
            autoExpandEnabled: settings.data.autoExpandEnabled,
            autoExpandRunning: autoExpand.status == .on,
            clipboard: clipboard
        )
    }
}
