import Testing
@testable import DOTLauncherCore

struct FuzzyMatcherTests {
    private func score(_ query: String, _ candidate: String) -> Double? {
        FuzzyMatcher.score(query, in: FuzzyTarget(candidate))
    }

    @Test func `matches a prefix`() {
        #expect(score("saf", "Safari") != nil)
    }

    @Test func `rejects a query that is not a subsequence`() {
        #expect(score("xyz", "Safari") == nil)
        #expect(score("safarix", "Safari") == nil)
    }

    @Test func `empty query matches everything with zero score`() {
        #expect(score("", "Safari") == 0)
    }

    @Test func `is case and diacritic insensitive`() {
        #expect(score("SAF", "safari") != nil)
        #expect(score("cafe", "Café") != nil)
    }

    @Test func `prefix match beats a mid-word match`() throws {
        let prefix = try #require(score("term", "Terminal"))
        let midWord = try #require(score("term", "Determine"))
        #expect(prefix > midWord)
    }

    @Test func `acronym of word starts beats scattered letters`() throws {
        let acronym = try #require(score("vsc", "Visual Studio Code"))
        let scattered = try #require(score("vsc", "Advanced Script Compiler"))
        #expect(acronym > scattered)
    }

    @Test func `camel case boundaries count as word starts`() throws {
        let camel = try #require(score("wa", "WhatsApp"))
        let inside = try #require(score("wa", "Swatch"))
        #expect(camel > inside)
    }

    @Test func `exact match beats a longer name with the same prefix`() throws {
        let exact = try #require(score("notes", "Notes"))
        let longer = try #require(score("notes", "Notes Helper"))
        #expect(exact > longer)
    }
}
