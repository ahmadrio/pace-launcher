import Foundation

/// Terminal escape sequences (colors, cursor moves, titles), which scripts
/// often print and which mean nothing in the launcher.
public enum ANSI {
    private static let pattern = try! NSRegularExpression(
        pattern: #"\u001B\[[0-9;?]*[ -/]*[@-~]|\u001B\][^\u0007\u001B]*(\u0007|\u001B\\)|\u001B[@-Z\\-_]"#
    )

    public static func strip(_ text: String) -> String {
        guard text.contains("\u{1B}") else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return pattern.stringByReplacingMatches(in: text, range: range, withTemplate: "")
    }
}
