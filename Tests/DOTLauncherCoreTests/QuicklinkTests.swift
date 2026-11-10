import Foundation
import Testing
@testable import DOTLauncherCore

private let urlMessage = "Enter a full URL, such as https://example.com/search?q={query}."

struct QuicklinkTests {
    private let defaults = Quicklink.defaults

    @Test func `query text is percent-encoded`() {
        let link = Quicklink(name: "G", keyword: "g", url: "https://x.test/s?q={query}&again={QUERY}")
        #expect(link.takesQuery)
        #expect(link.url(for: "a&b=c#d?e/f+g h")?.absoluteString
            == "https://x.test/s?q=a%26b%3Dc%23d%3Fe%2Ff%2Bg%20h&again=a%26b%3Dc%23d%3Fe%2Ff%2Bg%20h")
        #expect(link.url(for: "kopi ☕️")?.absoluteString == "https://x.test/s?q=kopi%20%E2%98%95%EF%B8%8F&again=kopi%20%E2%98%95%EF%B8%8F")
    }

    @Test func `links without a query open as they are`() {
        let mail = Quicklink(name: "Mail", keyword: nil, url: "https://mail.google.com")
        #expect(!mail.takesQuery)
        #expect(mail.url(for: "ignored")?.absoluteString == "https://mail.google.com")
    }

    @Test func `defaults cover common searches`() {
        #expect(defaults.map(\.name) == ["Google", "YouTube", "GitHub", "Google Maps"])
        #expect(defaults.map(\.keyword) == ["g", "yt", "gh", "maps"])
        #expect(defaults.allSatisfy { $0.takesQuery && $0.url(for: "x") != nil })
        #expect(Set(defaults.map(\.id)).count == 4)
        #expect(Quicklink.defaults == defaults)
    }

    @Test func `the keyword needs a space and text`() {
        let github = defaults.first { $0.keyword == "gh" }
        let match = Quicklinks.match("gh dot launcher", in: defaults)
        #expect(match?.link == github)
        #expect(match?.text == "dot launcher")
        #expect(Quicklinks.match("GH  Dot ", in: defaults)?.text == "Dot")
        for query in ["g", "g ", "gmail", "gh", "dot gh x", ""] {
            #expect(Quicklinks.match(query, in: defaults) == nil, "\(query)")
        }
        let mail = Quicklink(name: "Mail", keyword: "m", url: "https://mail.google.com")
        #expect(Quicklinks.match("m inbox", in: [mail]) == nil)
    }

    @Test func `urls need a scheme`() {
        func problem(_ url: String) -> String? {
            Quicklinks.problem(with: Quicklink(name: "X", keyword: nil, url: url), existing: [])
        }
        for bad in ["example.com/search?q={query}", "https://exa mple.com", "", "::"] {
            #expect(problem(bad) == urlMessage, "\(bad)")
        }
        #expect(problem("obsidian://open?vault={query}") == nil)
        #expect(problem("mailto:{query}") == nil)
        #expect(Quicklink(name: "X", keyword: nil, url: "example.com/{query}").url(for: "a") == nil)
    }

    @Test func `drafts are checked in order`() {
        let google = defaults[0]
        #expect(Quicklinks.problem(with: Quicklink(name: " ", keyword: "g h", url: ""), existing: defaults) == "Add a name.")
        #expect(Quicklinks.problem(with: Quicklink(name: "W", keyword: "g h", url: ""), existing: defaults) == "A keyword is one word, without spaces.")
        #expect(Quicklinks.problem(with: Quicklink(name: "W", keyword: "G", url: "https://w.test"), existing: defaults) == "Another quicklink uses this keyword.")
        var edited = google
        edited.name = "Google Search"
        #expect(Quicklinks.problem(with: edited, existing: defaults) == nil)
        #expect(Quicklinks.problem(with: Quicklink(name: "W", keyword: "  ", url: "https://w.test"), existing: defaults) == nil)
    }
}
