import Foundation

/// The fields PACE reads from GitHub's "latest release" answer. Only the
/// tag is used; URLs in the answer are ignored.
public struct GitHubRelease: Sendable, Equatable {
    public let tag: String
    public let version: AppVersion
    public let isDraft: Bool
    public let isPrerelease: Bool

    private struct Response: Decodable {
        let tag_name: String
        let draft: Bool?
        let prerelease: Bool?
    }

    /// Nil unless the answer is a release whose tag is a version.
    public static func decode(_ data: Data) -> GitHubRelease? {
        guard let response = try? JSONDecoder().decode(Response.self, from: data),
              let version = AppVersion(response.tag_name)
        else { return nil }
        return GitHubRelease(
            tag: response.tag_name, version: version,
            isDraft: response.draft ?? false, isPrerelease: response.prerelease ?? false
        )
    }
}
