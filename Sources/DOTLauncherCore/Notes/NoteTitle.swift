/// Titles and previews derived from a note's Markdown text.
public enum NoteTitle {
    /// The first non-empty line without leading `#`s, or "Untitled".
    public static func title(for body: String) -> String {
        guard let first = nonEmptyLines(body).first else { return "Untitled" }
        let title = first.drop { $0 == "#" }.trimmingCharacters(in: .whitespaces)
        return title.isEmpty ? "Untitled" : title
    }

    /// The second non-empty line, at most 80 characters, or "".
    public static func preview(for body: String) -> String {
        let lines = nonEmptyLines(body)
        guard lines.count > 1 else { return "" }
        return String(lines[1].prefix(80))
    }

    private static func nonEmptyLines(_ body: String) -> [String] {
        body.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
