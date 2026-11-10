public enum MarkdownSegment: Equatable, Sendable {
    case prose(String)
    /// A fenced block or inline code span, delimiters included.
    case code(String)
}

/// Splits Markdown into prose and code, so prose can be translated while
/// code is left untouched.
public enum MarkdownSegments {
    public static func split(_ text: String) -> [MarkdownSegment] {
        let characters = Array(text)
        var segments: [MarkdownSegment] = []
        var prose = ""
        var index = 0

        func flushProse() {
            if !prose.isEmpty {
                segments.append(.prose(prose))
                prose = ""
            }
        }

        while index < characters.count {
            if isFence(characters, at: index) {
                flushProse()
                var end = index + 3
                while end < characters.count, !isFence(characters, at: end) { end += 1 }
                end = min(end + 3, characters.count)   // include the closing fence, if any
                segments.append(.code(String(characters[index..<end])))
                index = end
            } else if characters[index] == "`", let close = closingBacktick(characters, after: index) {
                flushProse()
                segments.append(.code(String(characters[index...close])))
                index = close + 1
            } else {
                prose.append(characters[index])
                index += 1
            }
        }
        flushProse()
        return segments
    }

    public static func join(_ segments: [MarkdownSegment]) -> String {
        segments.map { segment in
            switch segment {
            case .prose(let text), .code(let text): text
            }
        }.joined()
    }

    private static func isFence(_ characters: [Character], at index: Int) -> Bool {
        index + 2 < characters.count
            && characters[index] == "`" && characters[index + 1] == "`" && characters[index + 2] == "`"
    }

    /// The next backtick on the same line, if any.
    private static func closingBacktick(_ characters: [Character], after index: Int) -> Int? {
        var cursor = index + 1
        while cursor < characters.count, !characters[cursor].isNewline {
            if characters[cursor] == "`" { return cursor }
            cursor += 1
        }
        return nil
    }

    /// Translates the prose of `markdown` paragraph by paragraph, keeping
    /// code and the blank lines and spaces around each paragraph. Checks for
    /// cancellation before every paragraph, because a translation already
    /// under way may not stop when asked.
    public static func translateProse(_ markdown: String, using translate: (String) async throws -> String) async throws -> String {
        var result: [MarkdownSegment] = []
        for segment in split(markdown) {
            guard case .prose(let prose) = segment else {
                result.append(segment)
                continue
            }
            var translated = ""
            for paragraph in paragraphs(of: prose) {
                let core = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !core.isEmpty, let range = paragraph.range(of: core) else {
                    translated += paragraph
                    continue
                }
                try Task.checkCancellation()
                translated += paragraph[..<range.lowerBound] + (try await translate(core)) + paragraph[range.upperBound...]
            }
            result.append(.prose(translated))
        }
        return join(result)
    }

    /// `prose` cut after each blank line; joining the pieces gives it back.
    private static func paragraphs(of prose: String) -> [Substring] {
        var pieces: [Substring] = []
        var rest = prose[...]
        while let gap = rest.range(of: #"\n[ \t]*\n\s*"#, options: .regularExpression) {
            pieces.append(rest[..<gap.upperBound])
            rest = rest[gap.upperBound...]
        }
        if !rest.isEmpty { pieces.append(rest) }
        return pieces
    }
}
