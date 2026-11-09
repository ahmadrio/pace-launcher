import DOTLauncherCore
import Foundation

/// Keeps the list of installed apps fresh. Scans run off the main actor.
final class AppIndexer {
    private let scanner = AppScanner.standard()
    private var lastScan = Date.distantPast
    private var isScanning = false

    private(set) var apps: [AppEntry] = []
    /// Called on the main actor after each completed scan.
    var onUpdate: (() -> Void)?

    /// Rescans when the index is older than `maxAge` seconds.
    func refreshIfStale(maxAge: TimeInterval = 60) {
        guard !isScanning, Date.now.timeIntervalSince(lastScan) > maxAge else { return }
        isScanning = true
        let started = ContinuousClock.now

        Task {
            let entries = await scanner.scanInBackground()
            apps = entries
            lastScan = .now
            isScanning = false
            let elapsed = started.duration(to: .now)
            Log.apps.info("indexed \(entries.count) apps in \(elapsed, privacy: .public)")
            onUpdate?()
        }
    }
}
