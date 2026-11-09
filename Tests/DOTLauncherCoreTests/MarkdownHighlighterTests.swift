import Foundation
import Testing
@testable import DOTLauncherCore

struct MarkdownHighlighterTests {
    private func span(_ kind: MarkdownSpan.Kind, _ location: Int, _ length: Int) -> MarkdownSpan {
        MarkdownSpan(range: NSRange(location: location, length: length), kind: kind)
    }

    @Test func `heading`() {
        let spans = MarkdownHighlighter.spans(in: "# Title")
        #expect(spans.contains(span(.heading(1), 0, 7)))
        #expect(spans.contains(span(.syntax, 0, 2)))
    }

    @Test func `level three heading`() {
        #expect(MarkdownHighlighter.spans(in: "### T").contains { $0.kind == .heading(3) })
    }

    @Test func `bold and italic`() {
        let spans = MarkdownHighlighter.spans(in: "a **b** _c_ *d*")
        #expect(spans.contains(span(.bold, 2, 5)))
        #expect(spans.contains(span(.syntax, 2, 2)))
        #expect(spans.contains(span(.syntax, 5, 2)))
        #expect(spans.contains(span(.italic, 8, 3)))
        #expect(spans.contains(span(.syntax, 8, 1)))
        #expect(spans.contains(span(.syntax, 10, 1)))
        #expect(spans.contains(span(.italic, 12, 3)))
        #expect(spans.contains(span(.syntax, 12, 1)))
        #expect(spans.contains(span(.syntax, 14, 1)))
        // The ** of bold is not mistaken for italics.
        #expect(!spans.contains { $0.kind == .italic && $0.range.location < 7 })
    }

    @Test func `strikethrough and inline code`() {
        let spans = MarkdownHighlighter.spans(in: "~~x~~ `y`")
        #expect(spans.contains(span(.strikethrough, 0, 5)))
        #expect(spans.contains(span(.inlineCode, 6, 3)))
    }

    @Test func `link`() {
        let spans = MarkdownHighlighter.spans(in: "[DOT](https://x.y)")
        #expect(spans.contains(span(.link, 0, 18)))
        #expect(spans.contains(span(.syntax, 0, 1)))
        #expect(spans.contains(span(.syntax, 4, 14)))
    }

    @Test func `list, task, quote`() {
        let spans = MarkdownHighlighter.spans(in: "- a\n- [ ] b\n- [x] c\n> q")
        #expect(spans.contains(span(.listMarker, 0, 2)))
        #expect(spans.contains(span(.listMarker, 4, 2)))
        #expect(spans.contains(span(.task(checked: false), 6, 3)))
        #expect(spans.contains(span(.task(checked: true), 14, 3)))
        #expect(spans.contains(span(.quote, 20, 3)))
    }

    @Test func `code fence suppresses inline styles`() {
        let text = "```\n**not bold**\n```"
        let spans = MarkdownHighlighter.spans(in: text)
        #expect(spans.filter { $0.kind == .codeBlock } == [span(.codeBlock, 0, (text as NSString).length)])
        #expect(!spans.contains { $0.kind == .bold })
    }

    @Test func `inline code suppresses other styles inside it`() {
        let spans = MarkdownHighlighter.spans(in: "`**x**`")
        #expect(spans.contains(span(.inlineCode, 0, 7)))
        #expect(!spans.contains { $0.kind == .bold })
    }

    @Test func `ranges are UTF-16 offsets`() {
        #expect(MarkdownHighlighter.spans(in: "😀 **b**").contains(span(.bold, 3, 5)))
    }

    @Test func `highlights a large note quickly`() {
        let block = """
        # Heading
        Some **bold** and _italic_ text with `code` and a [link](https://example.com).
        - [ ] task item
        > quoted line
        ```
        let x = 1
        ```
        """
        let text = Array(repeating: block, count: 2_000 / 7 + 1).joined(separator: "\n")

        let started = ContinuousClock.now
        let spans = MarkdownHighlighter.spans(in: text)
        let elapsed = started.duration(to: .now)

        #expect(!spans.isEmpty)
        #expect(elapsed < .milliseconds(100))
    }
}
