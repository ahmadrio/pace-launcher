import Foundation
import Testing
@testable import PACELauncherCore

private func version(_ text: String) throws -> AppVersion {
    try #require(AppVersion(text))
}

private func release(_ tag: String, draft: Bool = false, prerelease: Bool = false) throws -> GitHubRelease {
    try #require(GitHubRelease.decode(body(tag, draft: draft, prerelease: prerelease)))
}

private func body(_ tag: String, draft: Bool = false, prerelease: Bool = false) -> Data {
    Data(#"{"tag_name":"\#(tag)","draft":\#(draft),"prerelease":\#(prerelease),"html_url":"https://evil.example/x"}"#.utf8)
}

struct UpdateCheckTests {
    @Test func `reads versions`() throws {
        #expect(try version("1.2.3").description == "1.2.3")
        #expect(try version("v1.2.3").description == "1.2.3")
        #expect(try version("V1.2").description == "1.2.0")
        #expect(try version("2").description == "2.0.0")
        #expect(try version("v1.2").description == "1.2.0")
        for bad in ["", "v", "1.2.3.4", "1.2.3-beta", "1..2", " 1.2", "+1", "1.-2", "v1.2.3/../x", "1.2.", ".1", "1.٣"] {
            #expect(AppVersion(bad) == nil, "\(bad)")
        }
    }

    @Test func `compares versions`() throws {
        #expect(try version("1.0.0") < version("1.0.1"))
        #expect(try version("1.0.1") < version("1.1.0"))
        #expect(try version("1.1.0") < version("2.0.0"))
        #expect(try version("1.10.0") > version("1.9.0"))
        #expect(try version("1.0") == version("1.0.0"))
    }

    @Test func `decodes a release`() throws {
        let found = try release("v1.1.0")
        #expect(found.tag == "v1.1.0")
        #expect(found.version == (try version("1.1.0")))
        #expect(!found.isDraft)
        #expect(!found.isPrerelease)

        let bare = try #require(GitHubRelease.decode(Data(#"{"tag_name":"v2.0.0"}"#.utf8)))
        #expect(!bare.isDraft && !bare.isPrerelease)

        #expect(GitHubRelease.decode(body("nightly")) == nil)
        #expect(GitHubRelease.decode(Data("nonsense".utf8)) == nil)
        #expect(GitHubRelease.decode(Data("[]".utf8)) == nil)
    }

    @Test func `outcome maps every status`() throws {
        let current = try version("1.0.0")
        #expect(UpdateCheck.outcome(current: current, status: 200, body: body("v1.1.0")) == .available(try release("v1.1.0")))
        #expect(UpdateCheck.outcome(current: current, status: 200, body: body("v1.0.0")) == .upToDate)
        #expect(UpdateCheck.outcome(current: current, status: 200, body: body("v0.9.0")) == .upToDate)
        #expect(UpdateCheck.outcome(current: current, status: 200, body: body("v1.1.0", prerelease: true)) == .upToDate)
        #expect(UpdateCheck.outcome(current: current, status: 200, body: body("v1.1.0", draft: true)) == .upToDate)
        #expect(UpdateCheck.outcome(current: current, status: 200, body: Data("<html>".utf8)) == .failed("GitHub sent an answer PACE can’t read."))
        #expect(UpdateCheck.outcome(current: current, status: 404, body: Data()) == .noRelease)
        #expect(UpdateCheck.outcome(current: current, status: 403, body: Data()) == .failed("GitHub is limiting requests. Try again later."))
        #expect(UpdateCheck.outcome(current: current, status: 429, body: Data()) == .failed("GitHub is limiting requests. Try again later."))
        #expect(UpdateCheck.outcome(current: current, status: 500, body: Data()) == .failed("GitHub answered with status 500."))
    }

    @Test func `is due once a day`() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(UpdateCheck.isDue(lastSuccess: nil, now: now))
        #expect(!UpdateCheck.isDue(lastSuccess: now.addingTimeInterval(-23 * 3600), now: now))
        #expect(UpdateCheck.isDue(lastSuccess: now.addingTimeInterval(-24 * 3600), now: now))
        // The Mac's clock was set back: check instead of waiting for the old date.
        #expect(UpdateCheck.isDue(lastSuccess: now.addingTimeInterval(120), now: now))
        #expect(!UpdateCheck.isDue(lastSuccess: now.addingTimeInterval(30), now: now))
    }

    @Test func `release page comes from the repo, not the answer`() throws {
        #expect(UpdateCheck.releasePage(for: try release("v1.1.0")).absoluteString
            == "https://github.com/ahmadrio/pace-launcher/releases/tag/v1.1.0")
        #expect(UpdateCheck.latestReleaseAPI.absoluteString
            == "https://api.github.com/repos/ahmadrio/pace-launcher/releases/latest")
        #expect(GitHubRelease.decode(body("v1.2.3/../x")) == nil)
    }

    @Test func `announces each version once`() throws {
        #expect(UpdateCheck.shouldAnnounce(try release("v1.1.0"), announced: nil))
        #expect(!UpdateCheck.shouldAnnounce(try release("v1.1"), announced: "1.1.0"))
        #expect(UpdateCheck.shouldAnnounce(try release("v1.2.0"), announced: "1.1.0"))
    }
}
