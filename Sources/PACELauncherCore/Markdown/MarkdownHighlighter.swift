import Foundation

public struct MarkdownSpan: Equatable, Sendable {
    /// UTF-16 range in the text, ready for NSTextStorage.
    public let range: NSRange
    public let kind: Kind

    public enum Kind: Equatable, Sendable {
        case heading(Int)
        case bold
        case italic
        case strikethrough
        case inlineCode
        case codeBlock
        case link
        /// Markdown punctuation (`# `, `**`, `` ` ``, `[`, `](url)`, `> `),
        /// shown dimmed.
        case syntax
        case listMarker
        case task(checked: Bool)
        case quote
    }

    public init(range: NSRange, kind: Kind) {
        self.range = range
        self.kind = kind
    }
}

/// Finds the Markdown constructs in a note for live styling. It works line
/// by line, tracking fenced code blocks; the text itself is never changed.
public enum MarkdownHighlighter {
    public static func spans(in text: String) -> [MarkdownSpan] {
        let string = text as NSString
        var spans: [MarkdownSpan] = []
        var fenceStart: Int?
        var position = 0

        while position < string.length {
            var lineStart = 0, lineEnd = 0, contentsEnd = 0
            string.getLineStart(&lineStart, end: &lineEnd, contentsEnd: &contentsEnd, for: NSRange(location: position, length: 0))
            let line = NSRange(location: lineStart, length: contentsEnd - lineStart)
            position = lineEnd

            if isFence(string, line) {
                if let start = fenceStart {
                    spans.append(MarkdownSpan(range: NSRange(location: start, length: contentsEnd - start), kind: .codeBlock))
                    fenceStart = nil
                } else {
                    fenceStart = lineStart
                }
                continue
            }
            if fenceStart != nil { continue }
            highlightLine(string, line, into: &spans)
        }

        // An unclosed fence runs to the end of the note.
        if let start = fenceStart {
            spans.append(MarkdownSpan(range: NSRange(location: start, length: string.length - start), kind: .codeBlock))
        }
        return spans
    }

    // MARK: - Line rules

    private static func isFence(_ string: NSString, _ line: NSRange) -> Bool {
        string.substring(with: line).trimmingCharacters(in: .whitespaces).hasPrefix("```")
    }

    private static func highlightLine(_ string: NSString, _ line: NSRange, into spans: inout [MarkdownSpan]) {
        guard line.length > 0 else { return }
        let text = string as String

        if let match = heading.firstMatch(in: text, range: line) {
            let marks = match.range(at: 1)
            spans.append(MarkdownSpan(range: line, kind: .heading(marks.length)))
            spans.append(MarkdownSpan(range: NSRange(location: marks.location, length: match.range(at: 2).upperBound - marks.location), kind: .syntax))
        }
        if let match = quote.firstMatch(in: text, range: line) {
            spans.append(MarkdownSpan(range: line, kind: .quote))
            spans.append(MarkdownSpan(range: match.range, kind: .syntax))
        }
        if let match = listItem.firstMatch(in: text, range: line) {
            spans.append(MarkdownSpan(range: match.range(at: 1), kind: .listMarker))
            let task = match.range(at: 2)
            if task.location != NSNotFound {
                let checked = string.substring(with: task).lowercased() == "[x]"
                spans.append(MarkdownSpan(range: task, kind: .task(checked: checked)))
            }
        }

        // Inline code first: nothing else is styled inside it.
        var codeRanges: [NSRange] = []
        for match in inlineCode.matches(in: text, range: line) {
            codeRanges.append(match.range)
            spans.append(MarkdownSpan(range: match.range, kind: .inlineCode))
            spans.append(MarkdownSpan(range: NSRange(location: match.range.location, length: 1), kind: .syntax))
            spans.append(MarkdownSpan(range: NSRange(location: match.range.upperBound - 1, length: 1), kind: .syntax))
        }
        func outsideCode(_ range: NSRange) -> Bool {
            !codeRanges.contains { NSIntersectionRange($0, range).length > 0 }
        }

        let lineText = string.substring(with: line)
        for (pattern, kind, delimiter, trigger) in emphasisRules where lineText.contains(trigger) {
            for match in pattern.matches(in: text, range: line) where outsideCode(match.range) {
                spans.append(MarkdownSpan(range: match.range, kind: kind))
                spans.append(MarkdownSpan(range: NSRange(location: match.range.location, length: delimiter), kind: .syntax))
                spans.append(MarkdownSpan(range: NSRange(location: match.range.upperBound - delimiter, length: delimiter), kind: .syntax))
            }
        }

        if lineText.contains("](") {
            for match in link.matches(in: text, range: line) where outsideCode(match.range) {
                spans.append(MarkdownSpan(range: match.range, kind: .link))
                spans.append(MarkdownSpan(range: NSRange(location: match.range.location, length: 1), kind: .syntax))
                let closing = match.range(at: 1).upperBound   // the "]"
                spans.append(MarkdownSpan(range: NSRange(location: closing, length: match.range.upperBound - closing), kind: .syntax))
            }
        }
    }

    // MARK: - Patterns (compiled once)

    private static func regex(_ pattern: String) -> NSRegularExpression {
        // Patterns are constants; a failure here is a programming error.
        try! NSRegularExpression(pattern: pattern)
    }

    private static let heading = regex(#"^(#{1,6})(\s+)"#)
    private static let quote = regex(#"^>\s?"#)
    private static let listItem = regex(#"^\s*((?:[-*+]|\d+\.)\s+)(\[[ xX]\])?"#)
    private static let inlineCode = regex(#"`[^`]+`"#)
    private static let link = regex(#"\[([^\]]+)\]\([^)\s]+\)"#)

    /// (pattern, kind, delimiter length, substring that must be present)
    private static let emphasisRules: [(NSRegularExpression, MarkdownSpan.Kind, Int, String)] = [
        (regex(#"\*\*(?=\S)(.+?)(?<=\S)\*\*"#), .bold, 2, "**"),
        (regex(#"__(?=\S)(.+?)(?<=\S)__"#), .bold, 2, "__"),
        (regex(#"~~(?=\S)(.+?)(?<=\S)~~"#), .strikethrough, 2, "~~"),
        (regex(#"(?<![*\w])\*(?=[^\s*])([^*]+?)(?<=[^\s*])\*(?![*\w])"#), .italic, 1, "*"),
        (regex(#"(?<![_\w])_(?=[^\s_])([^_]+?)(?<=[^\s_])_(?![_\w])"#), .italic, 1, "_"),
    ]
}
