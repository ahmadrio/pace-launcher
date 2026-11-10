import Foundation
import Testing
@testable import PACELauncherCore

struct FrecencyTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func `more uses score higher`() {
        let few = Frecency.score(count: 2, lastUsed: now, now: now)
        let many = Frecency.score(count: 10, lastUsed: now, now: now)
        #expect(many > few)
    }

    @Test func `older use decays`() {
        let recent = Frecency.score(count: 5, lastUsed: now.addingTimeInterval(-86_400), now: now)
        let old = Frecency.score(count: 5, lastUsed: now.addingTimeInterval(-30 * 86_400), now: now)
        #expect(recent > old)
        #expect(old > 0)
    }

    @Test func `never used scores zero`() {
        #expect(Frecency.score(count: 0, lastUsed: now, now: now) == 0)
    }
}

struct ResultRankerTests {
    private func candidate(_ title: String, frecency: Double = 0, aliases: [String] = []) -> SearchCandidate<String> {
        SearchCandidate(id: title, title: title, aliases: aliases, frecency: frecency)
    }

    @Test func `drops candidates that do not match`() {
        let ranked = ResultRanker.rank("saf", [candidate("Safari"), candidate("Mail")], limit: 10)
        #expect(ranked == ["Safari"])
    }

    @Test func `frecency breaks ties between equal matches`() {
        let ranked = ResultRanker.rank(
            "te",
            [candidate("TextEdit", frecency: 0), candidate("Terminal", frecency: 3)],
            limit: 10
        )
        #expect(ranked == ["Terminal", "TextEdit"])
    }

    @Test func `a much better match still beats a frequently used weak match`() {
        let ranked = ResultRanker.rank(
            "notes",
            [candidate("Notes"), candidate("Nota Estimates", frecency: 2)],
            limit: 10
        )
        #expect(ranked.first == "Notes")
    }

    @Test func `matches on aliases`() {
        let ranked = ResultRanker.rank("code", [candidate("Visual Studio Code", aliases: ["Code"]), candidate("Mail")], limit: 10)
        #expect(ranked == ["Visual Studio Code"])
    }

    @Test func `empty query lists only used items by frecency`() {
        let ranked = ResultRanker.rank(
            "",
            [candidate("Mail"), candidate("Safari", frecency: 1), candidate("Notes", frecency: 5)],
            limit: 10
        )
        #expect(ranked == ["Notes", "Safari"])
    }

    @Test func `respects the limit`() {
        let candidates = (0..<20).map { candidate("App \($0)") }
        #expect(ResultRanker.rank("app", candidates, limit: 5).count == 5)
    }

    @Test func `ties fall back to alphabetical order`() {
        let ranked = ResultRanker.rank("", [candidate("Beta", frecency: 1), candidate("Alpha", frecency: 1)], limit: 10)
        #expect(ranked == ["Alpha", "Beta"])
    }
}
