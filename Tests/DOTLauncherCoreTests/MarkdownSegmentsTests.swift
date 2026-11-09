import Testing
@testable import DOTLauncherCore

struct MarkdownSegmentsTests {
    @Test func `plain text is one prose segment`() {
        #expect(MarkdownSegments.split("Just some words.") == [.prose("Just some words.")])
    }

    @Test func `fenced blocks are kept as code`() {
        let text = "Run:\n```swift\nlet a = 1\n```\nDone"
        #expect(MarkdownSegments.split(text) == [
            .prose("Run:\n"),
            .code("```swift\nlet a = 1\n```"),
            .prose("\nDone"),
        ])
    }

    @Test func `inline code is kept`() {
        #expect(MarkdownSegments.split("Use `ls -la` here") == [
            .prose("Use "),
            .code("`ls -la`"),
            .prose(" here"),
        ])
    }

    @Test func `an unterminated fence runs to the end`() {
        #expect(MarkdownSegments.split("See:\n```\nopen code") == [
            .prose("See:\n"),
            .code("```\nopen code"),
        ])
    }

    @Test func `a lone backtick stays prose`() {
        #expect(MarkdownSegments.split("it`s fine\nreally") == [.prose("it`s fine\nreally")])
    }

    @Test(arguments: [
        "",
        "No code at all",
        "Mix `a` and ```\nb\n``` and `c`",
        "Unclosed ```\nfence",
        "Backtick ` alone\nthen `code`",
    ])
    func `join is the inverse of split`(text: String) {
        #expect(MarkdownSegments.join(MarkdownSegments.split(text)) == text)
    }
}
