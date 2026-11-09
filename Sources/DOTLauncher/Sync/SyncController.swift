import AppKit
import DOTLauncherCore
import Observation

/// Opt-in storage in iCloud Drive plus rotating clipboard backups.
///
/// While sync is off nothing here reads or writes the iCloud folder: every
/// iCloud operation starts with `guard isEnabled`. The one exception is
/// `deleteBackups()`, which only runs when the user presses that button.
@Observable
final class SyncController {
    struct Backup: Identifiable, Equatable {
        let url: URL
        let date: Date
        /// False while iCloud has only a placeholder on this Mac.
        let isDownloaded: Bool
        var id: URL { url }
    }

    struct RestoreChoice: Equatable {
        let backup: Backup
        /// nil until the backup has downloaded and been counted.
        var clips: Int?
    }

    private(set) var isEnabled = AppPaths.syncEnabled
    private(set) var isBusy = false
    private(set) var backups: [Backup] = []
    var lastBackup: Date? { backups.first?.date }
    /// Set when backups from an earlier install exist: automatic backups
    /// wait until the user restores one or keeps the current history.
    private(set) var pendingRestoreChoice: RestoreChoice?
    private(set) var status: String?
    private(set) var statusIsError = false
    /// The action waiting for its confirming second press.
    private(set) var armedAction: String?

    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let clipboard: ClipboardStore?
    @ObservationIgnored private let beforeMove: () -> Void
    @ObservationIgnored private let afterMove: () -> Void
    @ObservationIgnored private var timer: Task<Void, Never>?
    @ObservationIgnored private var confirmation = PressConfirmation()
    @ObservationIgnored private var disarmTask: Task<Void, Never>?

    static let backupInterval: TimeInterval = 6 * 3600
    static let keptBackups = 5
    private static let pendingChoiceKey = "syncRestoreChoicePending"
    /// What moves between this Mac and iCloud Drive. SQLite never does.
    private static let items = ["Snippets", "Notes", "Scripts", "settings.json"]

    /// `beforeMove` saves pending edits; `afterMove` reloads everything
    /// that reads from the data folder.
    init(settings: SettingsStore, clipboard: ClipboardStore?, beforeMove: @escaping () -> Void, afterMove: @escaping () -> Void) {
        self.settings = settings
        self.clipboard = clipboard
        self.beforeMove = beforeMove
        self.afterMove = afterMove
    }

    private var backupFolder: URL { AppPaths.iCloudRoot.appending(path: "Backups") }

    /// At launch: resume backups and downloads when sync is on.
    func start() {
        guard isEnabled else { return }
        refreshBackups()
        downloadPlaceholders()
        scheduleBackups()
        Task {
            if UserDefaults.standard.bool(forKey: Self.pendingChoiceKey) {
                await preparePendingChoice()
            } else {
                await backupIfDue()
            }
        }
    }

    // MARK: - On / off

    func setEnabled(_ on: Bool) async throws {
        guard on != isEnabled, !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            if on { try await turnOn() } else { try await turnOff() }
        } catch {
            report(error.localizedDescription, isError: true)
            Log.app.error("sync \(on ? "on" : "off", privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    private func turnOn() async throws {
        try Self.checkICloudAvailable()
        beforeMove()
        let renamed = try Self.migrate(from: AppPaths.localRoot, to: AppPaths.iCloudRoot, label: "This Mac")
        UserDefaults.standard.set(true, forKey: AppPaths.syncEnabledKey)
        isEnabled = true
        afterMove()
        Log.app.notice("sync turned on")

        refreshBackups()
        scheduleBackups()
        downloadPlaceholders()
        report(renamed == 0
            ? "Your snippets, notes, scripts and settings are now in iCloud Drive › DOT Launcher."
            : "Moved to iCloud Drive › DOT Launcher. \(renamed) file(s) already existed there and were kept; this Mac’s copies got “(from This Mac)” in their name.")
        if backups.isEmpty {
            await backupNow()
        } else {
            UserDefaults.standard.set(true, forKey: Self.pendingChoiceKey)
            await preparePendingChoice()
        }
    }

    private func turnOff() async throws {
        // Bring evicted files down first, so nothing is left behind.
        let waiting = await waitForDownloads(timeout: .seconds(30))
        guard waiting == 0 else { throw SyncError.stillDownloading(waiting) }

        beforeMove()
        timer?.cancel()
        timer = nil
        let renamed = try Self.migrate(from: AppPaths.iCloudRoot, to: AppPaths.localRoot, label: "iCloud")
        UserDefaults.standard.set(false, forKey: AppPaths.syncEnabledKey)
        UserDefaults.standard.removeObject(forKey: Self.pendingChoiceKey)
        isEnabled = false
        backups = []
        pendingRestoreChoice = nil
        afterMove()
        Log.app.notice("sync turned off")
        report((renamed == 0 ? "Your data is back on this Mac." : "Your data is back on this Mac; \(renamed) file(s) got “(from iCloud)” in their name to keep both copies.")
            + " Clipboard backups in iCloud Drive were kept; delete them below if you want.")
    }

    /// Moves every synced item; on failure, moves back what this run moved
    /// so the app never shows half the data. Returns how many were renamed.
    private static func migrate(from source: URL, to destination: URL, label: String) throws -> Int {
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        var renamed = 0
        var done: [String] = []
        do {
            for item in items {
                done.append(item)
                let report = try FolderMigration.move(from: source.appending(path: item), to: destination.appending(path: item), label: label)
                renamed += report.renamed.count
                removeIfEmpty(source.appending(path: item))
            }
        } catch {
            for item in done {
                _ = try? FolderMigration.move(from: destination.appending(path: item), to: source.appending(path: item), label: label == "iCloud" ? "This Mac" : "iCloud")
            }
            throw error
        }
        return renamed
    }

    private static func removeIfEmpty(_ folder: URL) {
        var isFolder: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folder.path, isDirectory: &isFolder), isFolder.boolValue,
              (try? FileManager.default.contentsOfDirectory(atPath: folder.path))?.isEmpty == true
        else { return }
        try? FileManager.default.removeItem(at: folder)
    }

    private static func checkICloudAvailable() throws {
        // Test data with the real iCloud Drive would mix the two.
        if AppPaths.isUsingTestFolders, !AppPaths.isICloudOverridden { throw SyncError.testFoldersNeedICloudOverride }
        let drive = AppPaths.iCloudRoot.deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: drive.path) else { throw SyncError.iCloudDriveOff }
    }

    // MARK: - Evicted files

    /// Asks iCloud to download every placeholder in the synced folders.
    func downloadPlaceholders() {
        guard isEnabled else { return }
        for placeholder in placeholderFiles() { requestDownload(placeholder) }
    }

    private func placeholderFiles() -> [URL] {
        guard isEnabled else { return [] }
        return Self.items.flatMap { item -> [URL] in
            let folder = AppPaths.iCloudRoot.appending(path: item)
            guard let enumerator = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil) else { return [] }
            return enumerator.compactMap { $0 as? URL }.filter { ICloudPlaceholder.originalName(of: $0.lastPathComponent) != nil }
        }
    }

    private func requestDownload(_ placeholder: URL) {
        guard let name = ICloudPlaceholder.originalName(of: placeholder.lastPathComponent) else { return }
        let original = placeholder.deletingLastPathComponent().appending(path: name)
        do {
            try FileManager.default.startDownloadingUbiquitousItem(at: original)
        } catch {
            Log.app.debug("download request failed for \(name, privacy: .private): \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Returns how many placeholders are still waiting after `timeout`.
    private func waitForDownloads(timeout: Duration) async -> Int {
        let deadline = ContinuousClock.now + timeout
        while true {
            let pending = placeholderFiles()
            if pending.isEmpty || ContinuousClock.now >= deadline { return pending.count }
            pending.forEach(requestDownload)
            try? await Task.sleep(for: .seconds(1))
        }
    }

    /// The local file of a backup, downloading it first when needed.
    private func downloadedFile(_ backup: Backup) async -> URL? {
        guard isEnabled else { return nil }
        if backup.isDownloaded { return backup.url }
        guard let name = ICloudPlaceholder.originalName(of: backup.url.lastPathComponent) else { return nil }
        let original = backup.url.deletingLastPathComponent().appending(path: name)
        requestDownload(backup.url)
        let deadline = ContinuousClock.now + .seconds(60)
        while ContinuousClock.now < deadline {
            if FileManager.default.fileExists(atPath: original.path) { return original }
            try? await Task.sleep(for: .seconds(1))
        }
        return nil
    }

    // MARK: - Backups

    var wantsBackupOnQuit: Bool {
        isEnabled && settings.data.includeClipboardInBackup && pendingRestoreChoice == nil && clipboard != nil
    }

    private func refreshBackups() {
        guard isEnabled else {
            backups = []
            return
        }
        backups = BackupRotation.backups(in: backupFolder).map { entry in
            Backup(url: entry.url, date: entry.date, isDownloaded: ICloudPlaceholder.originalName(of: entry.url.lastPathComponent) == nil)
        }
    }

    /// Writes a backup now (when allowed) and keeps the newest five.
    func backupNow() async {
        guard isEnabled, settings.data.includeClipboardInBackup, pendingRestoreChoice == nil, let clipboard else { return }
        let folder = backupFolder
        // Back up next to the database first, then move the finished file
        // into iCloud, so iCloud never uploads a half-written backup.
        let staging = AppPaths.localRoot.appending(path: ".backup-in-progress.sqlite")
        do {
            try? FileManager.default.removeItem(at: staging)
            try await clipboard.backup(to: staging.path)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let target = folder.appending(path: BackupRotation.fileName(for: .now))
            if FileManager.default.fileExists(atPath: target.path) {
                _ = try FileManager.default.replaceItemAt(target, withItemAt: staging)
            } else {
                try FileManager.default.moveItem(at: staging, to: target)
            }
            try BackupRotation.prune(in: folder, keep: Self.keptBackups)
            Log.app.notice("clipboard backup written")
        } catch {
            try? FileManager.default.removeItem(at: staging)
            Log.app.error("clipboard backup failed: \(error.localizedDescription, privacy: .public)")
            report("Backup failed: \(error.localizedDescription)", isError: true)
        }
        refreshBackups()
    }

    func backupIfDue() async {
        guard isEnabled else { return }
        refreshBackups()
        // A little slack: file names only keep the minute.
        if let last = lastBackup, Date.now.timeIntervalSince(last) < Self.backupInterval - 120 { return }
        await backupNow()
    }

    private func scheduleBackups() {
        timer?.cancel()
        timer = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15 * 60))
                guard !Task.isCancelled else { return }
                await self?.backupIfDue()
            }
        }
    }

    /// Called from `applicationShouldTerminate`.
    func backupOnQuit() async {
        await backupNow()
    }

    // MARK: - Restore

    private func preparePendingChoice() async {
        refreshBackups()
        guard isEnabled, let newest = backups.first else {
            pendingRestoreChoice = nil
            UserDefaults.standard.removeObject(forKey: Self.pendingChoiceKey)
            return
        }
        pendingRestoreChoice = RestoreChoice(backup: newest, clips: nil)
        if let file = await downloadedFile(newest) {
            let count = Self.clipCount(at: file)
            if pendingRestoreChoice?.backup == newest { pendingRestoreChoice?.clips = count }
        }
    }

    /// Clips in a backup, counted on a local copy.
    private static func clipCount(at url: URL) -> Int? {
        let copy = FileManager.default.temporaryDirectory.appending(path: "dot-count-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: copy) }
        guard (try? FileManager.default.copyItem(at: url, to: copy)) != nil,
              let db = try? SQLiteDatabase(path: copy.path, readOnly: true),
              let count = try? db.query("SELECT COUNT(*) AS n FROM clips").first?.int("n")
        else { return nil }
        return Int(count)
    }

    /// Replaces the local clipboard history with a backup. The current
    /// history is saved first as `clipboard-before-restore.sqlite`.
    func restore(_ backup: Backup) async {
        guard isEnabled, let clipboard, !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        guard let file = await downloadedFile(backup) else {
            report("That backup hasn’t downloaded from iCloud yet. Try again in a minute.", isError: true)
            return
        }
        let staging = AppPaths.localRoot.appending(path: ".restore-in-progress.sqlite")
        do {
            try await clipboard.backup(to: AppPaths.localRoot.appending(path: "clipboard-before-restore.sqlite").path)
            try? FileManager.default.removeItem(at: staging)
            try FileManager.default.copyItem(at: file, to: staging)
            defer { try? FileManager.default.removeItem(at: staging) }
            try await clipboard.restore(from: staging.path)
            let count = try await clipboard.count()
            pendingRestoreChoice = nil
            UserDefaults.standard.removeObject(forKey: Self.pendingChoiceKey)
            Log.app.notice("clipboard history restored from a backup")
            report("Restored \(count) clips from the backup of \(backup.date.formatted(date: .abbreviated, time: .shortened)). The previous history was saved as clipboard-before-restore.sqlite.")
        } catch {
            Log.app.error("restore failed: \(error.localizedDescription, privacy: .public)")
            report("Restore failed: \(error.localizedDescription)", isError: true)
        }
    }

    /// "Keep current history": resume automatic backups.
    func keepCurrentHistory() async {
        pendingRestoreChoice = nil
        UserDefaults.standard.removeObject(forKey: Self.pendingChoiceKey)
        report("Kept the current clipboard history. Automatic backups are on again.")
        await backupNow()
    }

    /// Deletes every clipboard backup in iCloud Drive. Runs only when the
    /// user presses the button, even while sync is off (privacy).
    func deleteBackups() {
        let folder = backupFolder
        let all = BackupRotation.backups(in: folder)
        var failed = 0
        for backup in all {
            do { try FileManager.default.removeItem(at: backup.url) } catch { failed += 1 }
        }
        Self.removeIfEmpty(folder)
        if !isEnabled { Self.removeIfEmpty(AppPaths.iCloudRoot) }
        pendingRestoreChoice = nil
        UserDefaults.standard.removeObject(forKey: Self.pendingChoiceKey)
        refreshBackups()
        Log.app.notice("deleted \(all.count - failed, privacy: .public) iCloud clipboard backups")
        report(failed == 0 ? "Deleted \(all.count) clipboard backup(s) from iCloud Drive." : "Deleted \(all.count - failed) backup(s); \(failed) could not be deleted.", isError: failed > 0)
    }

    // MARK: - Press-again confirmation

    /// First press arms `action`, a second press within 3 s confirms it.
    func confirm(_ action: String) -> Bool {
        let confirmed = confirmation.press(action, at: .now)
        armedAction = confirmed ? nil : action
        disarmTask?.cancel()
        if !confirmed {
            disarmTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
                self?.armedAction = nil
            }
        }
        return confirmed
    }

    private func report(_ message: String, isError: Bool = false) {
        status = message
        statusIsError = isError
    }
}

enum SyncError: LocalizedError {
    case iCloudDriveOff
    case testFoldersNeedICloudOverride
    case stillDownloading(Int)

    var errorDescription: String? {
        switch self {
        case .iCloudDriveOff:
            "iCloud Drive isn’t on for this Mac. Turn it on in System Settings › Apple Account › iCloud, then try again."
        case .testFoldersNeedICloudOverride:
            "Test data folders are in use but DOTiCloudRootOverride is not set, so sync stays off to keep test data out of your real iCloud Drive."
        case .stillDownloading(let count):
            "\(count) file(s) are still downloading from iCloud. Sync stays on so nothing is left behind; try again in a moment."
        }
    }
}
