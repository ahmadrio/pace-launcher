/// Size facts shown in the clipboard preview.
public enum ClipStats {
    /// "1 character", "5 characters", "5 characters · 2 lines".
    public static func summary(for text: String) -> String {
        let characters = text.count
        var summary = characters == 1 ? "1 character" : "\(characters) characters"
        let lines = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).count
        if lines > 1 { summary += " · \(lines) lines" }
        return summary
    }
}
