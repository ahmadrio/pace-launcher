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

    @Test func `a bare keyword does not lift a quicklink above a used app`() {
        var chrome = SearchCandidate(id: "app:chrome", title: "Google Chrome")
        chrome.frecency = 1
        var github = SearchCandidate(id: "app:github", title: "GitHub Desktop")
        github.frecency = 1
        let links = defaults.map { Quicklinks.searchCandidate(for: $0, id: "quicklink:" + $0.name) }
        #expect(ResultRanker.rank("g", links + [chrome], limit: 5).first == "app:chrome")
        #expect(ResultRanker.rank("gh", links + [github], limit: 5).first == "app:github")
        #expect(ResultRanker.rank("goo", links, limit: 5).first == "quicklink:Google")
    }

    @Test func `urls with non-ASCII letters or bars are accepted`() {
        #expect(Quicklink(name: "B", keyword: nil, url: "https://bücher.de/?q={query}").url(for: "a")?.absoluteString == "https://xn--bcher-kva.de/?q=a")
        #expect(Quicklinks.problem(with: Quicklink(name: "S", keyword: nil, url: "https://example.com/søk?q={query}"), existing: []) == nil)
        #expect(Quicklinks.problem(with: Quicklink(name: "P", keyword: nil, url: "https://e.com/?a=b|c&q={query}"), existing: []) == nil)
        #expect(Quicklinks.problem(with: Quicklink(name: "X", keyword: nil, url: "https://exa mple.com"), existing: []) == urlMessage)
        #expect(Quicklinks.problem(with: Quicklink(name: "X", keyword: nil, url: "https://e.com/a b?q={query}"), existing: []) == urlMessage)
    }

    @Test func `typed text is encoded once even when the template needs fixing`() {
        #expect(Quicklink(name: "P", keyword: nil, url: "https://e.com/?a=b|c&q={query}").url(for: "a b")?.absoluteString
            == "https://e.com/?a=b%7Cc&q=a%20b")
        #expect(Quicklink(name: "S", keyword: nil, url: "https://example.com/søk/{query}").url(for: "café")?.absoluteString
            == "https://example.com/s%C3%B8k/caf%C3%A9")
        #expect(Quicklink(name: "F", keyword: nil, url: "https://e.com/?q={query}&lang=français").url(for: "dot launcher")?.absoluteString
            == "https://e.com/?q=dot%20launcher&lang=fran%C3%A7ais")
    }

    @Test func `readable hosts`() {
        #expect(Quicklink(name: "B", keyword: nil, url: "https://bücher.de/?q={query}").displayHost == "bücher.de")
        #expect(Quicklink.defaults[2].displayHost == "github.com")
        #expect(Quicklink(name: "Slack", keyword: nil, url: "https://{query}.slack.com").displayHost == "{query}.slack.com")
        #expect(Quicklink(name: "Vercel", keyword: nil, url: "https://{QUERY}.vercel.app/x").displayHost == "{query}.vercel.app")
    }

    @Test func `quicklinks remember their browser`() throws {
        func decode(_ json: String) throws -> [Quicklink] {
            try JSONDecoder().decode(SettingsData.self, from: Data(json.utf8)).quicklinks
        }
        let safari = try decode(#"{"quicklinks": [{"name": "A", "url": "https://a.test", "browser": "com.apple.Safari"}]}"#)
        #expect(safari.first?.browser == "com.apple.Safari")
        #expect(try decode(#"{"quicklinks": [{"name": "A", "url": "https://a.test"}]}"#).first?.browser == nil)
        let odd = try decode(#"{"quicklinks": [{"name": "A", "url": "https://a.test", "browser": 42}]}"#)
        #expect(odd.count == 1)
        #expect(odd.first?.browser == nil)
        let link = Quicklink(name: "B", keyword: "b", url: "https://b.test/{query}", browser: "com.brave.Browser")
        #expect(try JSONDecoder().decode(Quicklink.self, from: JSONEncoder().encode(link)) == link)
    }

    @Test func `browsers are named, not shown as bundle ids`() {
        #expect(BrowserNames.displayName(for: "company.thebrowser.Browser") == "Arc")
        #expect(BrowserNames.displayName(for: "com.google.Chrome") == "Google Chrome")
        #expect(BrowserNames.displayName(for: "COM.APPLE.SAFARI") == "Safari")
        #expect(BrowserNames.displayName(for: "com.example.coolbrowser") == "coolbrowser")
    }

    @Test func `blank browsers mean the default`() throws {
        for value in ["\"\"", "\"  \""] {
            let json = #"{"quicklinks": [{"name": "A", "url": "https://a.test", "browser": "# + value + "}]}"
            #expect(try JSONDecoder().decode(SettingsData.self, from: Data(json.utf8)).quicklinks.first?.browser == nil)
        }
    }
}

