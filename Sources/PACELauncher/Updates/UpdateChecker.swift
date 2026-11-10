import AppKit
import Observation
import PACELauncherCore

/// Asks GitHub Releases whether a newer PACE exists: automatically about
/// once a day (when allowed), or on request. It only tells the user and
/// opens the release page; it never downloads or installs anything.
@Observable
final class UpdateChecker {
    /// A newer release found by the last successful check.
    private(set) var available: GitHubRelease?
    /// When GitHub last answered (a release or "none").
    private(set) var lastSuccess: Date?
    private(set) var isChecking = false
    /// This build's version; nil (no checks) if Info.plist has none.
    let current = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String).flatMap(AppVersion.init)

    /// True while automatic checks must wait (the welcome window is open,
    /// so the user has not seen the setting yet).
    @ObservationIgnored var isPaused: () -> Bool = { false }
    /// An automatic check found a version the user was not told about.
    @ObservationIgnored var onAnnounce: (GitHubRelease) -> Void = { _ in }

    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let url: URL
    @ObservationIgnored private let hasOverride: Bool
    /// A manual check is waiting for the running check's answer.
    @ObservationIgnored private var alertWhenDone = false
    @ObservationIgnored private var loop: Task<Void, Never>?
    /// No cookies or disk cache, and generic headers instead of the
    /// system's languages and version. GitHub requires a User-Agent.
    @ObservationIgnored private let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpAdditionalHeaders = [
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
            "Accept-Language": "en",
            "User-Agent": "PACELauncher",
        ]
        return URLSession(configuration: configuration)
    }()

    init(settings: SettingsStore, defaults: UserDefaults = .standard) {
        self.settings = settings
        self.defaults = defaults
        // Test hook, like PACERatesURLOverride: a local server instead of GitHub.
        let override = defaults.string(forKey: "PACEUpdatesURLOverride").flatMap(URL.init(string:))
        url = override ?? UpdateCheck.latestReleaseAPI
        hasOverride = override != nil
        lastSuccess = defaults.object(forKey: Self.key("lastUpdateCheck")) as? Date
        // A release found before a relaunch stays offered until the next
        // answer; it is dropped once this build has caught up with it.
        if let tag = defaults.string(forKey: Self.key("availableUpdateTag")),
           let release = GitHubRelease(tag: tag), let current, release.version > current {
            available = release
        }
    }

    /// First try 10 s after launch, then every hour; each try only asks
    /// GitHub when a day has passed since its last answer.
    func start() {
        guard loop == nil else { return }
        loop = Task { [weak self] in
            try? await Task.sleep(for: .seconds(10))
            while !Task.isCancelled {
                self?.checkIfDue()
                try? await Task.sleep(for: .seconds(3600))
            }
        }
    }

    /// An automatic check, when every condition allows one.
    func checkIfDue() {
        guard settings.data.checkForUpdates else {
            Log.app.debug("update check skipped: turned off")
            return
        }
        guard !isPaused() else {
            Log.app.debug("update check skipped: welcome window open")
            return
        }
        guard hasOverride || !AppPaths.isUsingTestFolders else {
            Log.app.debug("update check skipped: test data folders without PACEUpdatesURLOverride")
            return
        }
        guard current != nil, !isChecking, UpdateCheck.isDue(lastSuccess: lastSuccess, now: .now) else { return }
        check()
    }

    /// The user asked: always checks, and answers with a dialog. While a
    /// check runs, its answer is the one shown.
    func checkNow() {
        alertWhenDone = true
        guard !isChecking else { return }
        check()
    }

    func openDownloadPage() {
        guard let available else { return }
        NSWorkspace.shared.open(UpdateCheck.releasePage(for: available))
    }

    private static func key(_ base: String) -> String {
        MachineDefaults.key(base, usingTestFolders: AppPaths.isUsingTestFolders)
    }

    private func check() {
        guard let current else {
            Log.app.error("update check impossible: no CFBundleShortVersionString")
            return
        }
        isChecking = true
        Task {
            let outcome = await fetch(current: current)
            finish(outcome, current: current)
        }
    }

    private func fetch(current: AppVersion) async -> UpdateCheck.Outcome {
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        do {
            let (data, response) = try await session.data(for: request)
            guard let status = (response as? HTTPURLResponse)?.statusCode else {
                return .failed("GitHub sent an answer PACE can’t read.")
            }
            return UpdateCheck.outcome(current: current, status: status, body: data)
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    private func finish(_ outcome: UpdateCheck.Outcome, current: AppVersion) {
        isChecking = false
        let manual = alertWhenDone
        alertWhenDone = false
        switch outcome {
        case .available(let release):
            rememberAnswer()
            available = release
            defaults.set(release.tag, forKey: Self.key("availableUpdateTag"))
            Log.app.notice("update check: \(release.version.description, privacy: .public) is available (running \(current.description, privacy: .public))")
            let announcedKey = Self.key("announcedUpdateVersion")
            if UpdateCheck.shouldAnnounce(release, announced: defaults.string(forKey: announcedKey)) {
                defaults.set(release.version.description, forKey: announcedKey)
                // A manual check says it in its dialog instead.
                if !manual { onAnnounce(release) }
            }
        case .upToDate, .noRelease:
            rememberAnswer()
            available = nil
            defaults.removeObject(forKey: Self.key("availableUpdateTag"))
            Log.app.notice("update check: \(outcome == .noRelease ? "no release published" : "up to date", privacy: .public)")
        case .failed(let reason):
            // A failed check is tried again on the next hourly tick.
            Log.app.notice("update check failed: \(reason, privacy: .public)")
        }
        if manual {
            UpdateAlert.show(outcome, current: current) { [weak self] _ in self?.openDownloadPage() }
        }
    }

    private func rememberAnswer() {
        let now = Date.now
        lastSuccess = now
        defaults.set(now, forKey: Self.key("lastUpdateCheck"))
    }
}
