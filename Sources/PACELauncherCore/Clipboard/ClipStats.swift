/// Size facts shown in the clipboard preview.
public enum ClipStats {
    /// The beginning of a clip for the preview pane: laying out megabytes
    /// of text would freeze the panel. Costs O(limit), not O(text).
    public static func preview(of text: String, limit: Int = 20_000) -> (text: String, isTruncated: Bool) {
        guard let end = text.index(text.startIndex, offsetBy: limit, limitedBy: text.endIndex), end < text.endIndex else {
            return (text, false)
        }
        return (String(text[..<end]), true)
    }

    /// "1 character", "5 characters", "5 characters · 2 lines".
    public static func summary(for text: String) -> String {
        let characters = text.count
        var summary = characters == 1 ? "1 character" : "\(characters) characters"
        let lines = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).count
        if lines > 1 { summary += " · \(lines) lines" }
        return summary
    }
}
