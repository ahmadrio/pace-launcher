import Foundation

/// Decides what a check of GitHub Releases means. PACE only tells the user
/// about a new version and opens its release page; it never installs.
public enum UpdateCheck {
    /// The GitHub repository releases are published in.
    public static let repository = "ahmadrio/pace-launcher"
    public static let latestReleaseAPI = URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!
    /// Automatic checks wait this long after the last answer.
    public static let interval: TimeInterval = 24 * 3600

    public enum Outcome: Equatable, Sendable {
        case available(GitHubRelease)
        case upToDate
        /// GitHub has no published release (404).
        case noRelease
        case failed(String)
    }

    /// What GitHub's answer means for a Mac running `current`. Drafts and
    /// pre-releases never count as new.
    public static func outcome(current: AppVersion, status: Int, body: Data) -> Outcome {
        switch status {
        case 200:
            guard let release = GitHubRelease.decode(body) else {
                // A release tagged with something that is not a version is
                // ignored, not retried every hour.
                return GitHubRelease.isRelease(body) ? .upToDate : .failed("GitHub sent an answer PACE can’t read.")
            }
            let isNew = release.version > current && !release.isDraft && !release.isPrerelease
            return isNew ? .available(release) : .upToDate
        case 404:
            return .noRelease
        case 403, 429:
            return .failed("GitHub is limiting requests. Try again later.")
        default:
            return .failed("GitHub answered with status \(status).")
        }
    }

    /// Whether an automatic check may ask GitHub at all: the user allows it,
    /// their settings are loaded (not an iCloud placeholder standing in with
    /// defaults), nothing pauses it, and test data folders point at a
    /// local server.
    public static func mayCheckAutomatically(
        enabled: Bool, settingsLoaded: Bool, paused: Bool, usingTestFolders: Bool, hasOverride: Bool
    ) -> Bool {
        enabled && settingsLoaded && !paused && (hasOverride || !usingTestFolders)
    }

    /// A day after the last answer; also when that answer seems to come
    /// from the future (the Mac's clock was set back).
    public static func isDue(lastSuccess: Date?, now: Date) -> Bool {
        guard let lastSuccess else { return true }
        if lastSuccess.timeIntervalSince(now) > 60 { return true }
        return now.timeIntervalSince(lastSuccess) >= interval
    }

    /// The release page, built from the repository and the parsed tag, never
    /// from a URL in GitHub's answer.
    public static func releasePage(for release: GitHubRelease) -> URL {
        let tag = release.tag.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? release.version.description
        return URL(string: "https://github.com/\(repository)/releases/tag/\(tag)")!
    }

    /// True the first time a version is found; `announced` is the last
    /// version the user was told about.
    public static func shouldAnnounce(_ release: GitHubRelease, announced: String?) -> Bool {
        release.version.description != announced
    }
}
