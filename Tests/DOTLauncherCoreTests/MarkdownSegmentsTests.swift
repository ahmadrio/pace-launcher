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

struct ProseTranslationTests {
    private let markdown = "First paragraph.\n\nSecond paragraph.\n\n```\ncode\n```\n\nThird."

    @Test func `prose is translated paragraph by paragraph and code is kept`() async throws {
        var calls: [String] = []
        let result = try await MarkdownSegments.translateProse(markdown) { text in
            calls.append(text)
            return text.uppercased()
        }
        #expect(result == "FIRST PARAGRAPH.\n\nSECOND PARAGRAPH.\n\n```\ncode\n```\n\nTHIRD.")
        #expect(calls == ["First paragraph.", "Second paragraph.", "Third."])
    }

    @Test func `translation stops before the next paragraph once cancelled`() async {
        let text = markdown
        let task = Task { () -> (Result<String, any Error>, Int) in
            var calls = 0
            do {
                let result = try await MarkdownSegments.translateProse(text) { paragraph in
                    calls += 1
                    withUnsafeCurrentTask { $0?.cancel() }
                    return paragraph
                }
                return (.success(result), calls)
            } catch {
                return (.failure(error), calls)
            }
        }
        let (result, calls) = await task.value
        #expect(calls == 1)
        guard case .failure(let error) = result else {
            Issue.record("expected a cancellation")
            return
        }
        #expect(error is CancellationError)
    }
}
