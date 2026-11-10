/// Names a chat after its first question.
public enum ChatTitle {
    static let maxLength = 80

    /// The first non-empty line, trimmed and cut to 80 characters.
    public static func title(for prompt: String) -> String {
        let line = prompt
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty }
        guard let line else { return "New Chat" }
        guard line.count > maxLength else { return line }
        return String(line.prefix(maxLength - 1)) + "…"
    }
}
