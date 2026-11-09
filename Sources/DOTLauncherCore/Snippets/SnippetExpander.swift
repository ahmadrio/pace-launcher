import Foundation

/// Fills `{date}`, `{time}`, `{datetime}` and `{clipboard}` in snippet text.
/// Unknown placeholders are left as written. A single left-to-right pass,
/// so inserted text (like a clipboard containing "{date}") is never expanded.
public enum SnippetExpander {
    public static func expand(_ content: String, now: Date, clipboard: String?, timeZone: TimeZone = .current) -> String {
        guard content.contains("{") else { return content }

        func format(_ pattern: String) -> String {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = timeZone
            formatter.dateFormat = pattern
            return formatter.string(from: now)
        }

        func value(for name: Substring) -> String? {
            switch name {
            case "date": format("yyyy-MM-dd")
            case "time": format("HH:mm")
            case "datetime": format("yyyy-MM-dd HH:mm")
            case "clipboard": clipboard ?? ""
            default: nil
            }
        }

        var result = ""
        var rest = content[...]
        while let open = rest.firstIndex(of: "{") {
            result += rest[..<open]
            rest = rest[open...]
            guard let close = rest.firstIndex(of: "}") else { break }
            let name = rest[rest.index(after: open)..<close]
            result += value(for: name) ?? String(rest[open...close])
            rest = rest[rest.index(after: close)...]
        }
        return result + rest
    }
}
