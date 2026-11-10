import Testing
@testable import PACELauncherCore

struct KeywordExpanderTests {
    private func typeEach(_ text: String, into expander: inout KeywordExpander) -> [String?] {
        text.map { expander.type(String($0)) }
    }

    @Test func `completes a keyword`() {
        var expander = KeywordExpander(keywords: [";addr"])
        let results = typeEach(";addr", into: &expander)
        #expect(results.dropLast().allSatisfy { $0 == nil })
        #expect(results.last == ";addr")
    }

    @Test func `longest keyword wins`() {
        var expander = KeywordExpander(keywords: ["addr", ";addr"])
        #expect(typeEach(";addr", into: &expander).last == ";addr")
    }

    @Test func `a keyword that prefixes another fires first`() {
        // Expansion is immediate, so ";a" shadows ";addr" (the editor warns).
        var expander = KeywordExpander(keywords: [";a", ";addr"])
        #expect(typeEach(";a", into: &expander).last == ";a")
    }

    @Test func `suffix of the buffer only`() {
        var expander = KeywordExpander(keywords: [";addr"])
        #expect(typeEach("x;addr", into: &expander).last == ";addr")
    }

    @Test func `case-sensitive`() {
        var expander = KeywordExpander(keywords: [";Addr"])
        // `.last` is String?? — unwrap the element before comparing with nil.
        #expect(typeEach(";addr", into: &expander).last! == nil)
    }

    @Test func `backspace edits the buffer`() {
        var expander = KeywordExpander(keywords: [";addr"])
        _ = typeEach(";adx", into: &expander)
        expander.deleteBackward()
        #expect(typeEach("dr", into: &expander).last == ";addr")
    }

    @Test func `reset clears`() {
        var expander = KeywordExpander(keywords: [";addr"])
        _ = typeEach(";ad", into: &expander)
        expander.reset()
        #expect(typeEach("dr", into: &expander).last! == nil)
    }

    @Test func `the buffer is cleared after a match`() {
        var expander = KeywordExpander(keywords: [";a"])
        #expect(expander.type(";") == nil)
        #expect(expander.type("a") == ";a")
        #expect(expander.type("a") == nil)
    }

    @Test func `capacity bounds the buffer`() {
        var expander = KeywordExpander(keywords: [";addr"], capacity: 8)
        _ = typeEach(String(repeating: "x", count: 100), into: &expander)
        #expect(typeEach(";addr", into: &expander).last == ";addr")
    }

    @Test func `empty keywords are ignored`() {
        var expander = KeywordExpander(keywords: ["", ";x"])
        #expect(expander.type("q") == nil)
    }
}

struct AutoExpandRuleTests {
    @Test func `runs while typing in another app`() {
        #expect(AutoExpandRule.allows(frontmostBundleID: "com.apple.TextEdit", appIsFrontmost: false, appHasKeyWindow: false, excluded: []))
    }

    @Test func `never runs while a PACE panel has keyboard focus`() {
        // PACE's panels are non-activating: the app behind stays frontmost.
        #expect(!AutoExpandRule.allows(frontmostBundleID: "com.apple.finder", appIsFrontmost: false, appHasKeyWindow: true, excluded: []))
    }

    @Test func `never runs while PACE is frontmost`() {
        #expect(!AutoExpandRule.allows(frontmostBundleID: "io.github.ahmadrio.PACELauncher", appIsFrontmost: true, appHasKeyWindow: false, excluded: []))
    }

    @Test func `never runs in an excluded app`() {
        #expect(!AutoExpandRule.allows(frontmostBundleID: "com.apple.Terminal", appIsFrontmost: false, appHasKeyWindow: false, excluded: ["com.apple.Terminal"]))
    }
}
