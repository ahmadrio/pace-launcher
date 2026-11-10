import Foundation

/// A saved URL opened from the launcher. `{query}` in the URL is replaced
/// by the text typed after it.
public struct Quicklink: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var name: String
    /// nil or one word, typed before the text in the launcher ("gh dot").
    public var keyword: String?
    /// The template: "{query}" (any case) marks where the text goes.
    public var url: String

    public init(id: UUID = UUID(), name: String, keyword: String?, url: String) {
        self.id = id
        self.name = name
        self.keyword = keyword
        self.url = url
    }

    /// Seeded when settings.json has no quicklinks yet. Fixed ids keep their
    /// launch history across Macs.
    public static let defaults: [Quicklink] = [
        Quicklink(id: UUID(uuidString: "D07A0001-0000-4000-8000-000000000001")!, name: "Google", keyword: "g",
                  url: "https://www.google.com/search?q={query}"),
        Quicklink(id: UUID(uuidString: "D07A0001-0000-4000-8000-000000000002")!, name: "YouTube", keyword: "yt",
                  url: "https://www.youtube.com/results?search_query={query}"),
        Quicklink(id: UUID(uuidString: "D07A0001-0000-4000-8000-000000000003")!, name: "GitHub", keyword: "gh",
                  url: "https://github.com/search?q={query}"),
        Quicklink(id: UUID(uuidString: "D07A0001-0000-4000-8000-000000000004")!, name: "Google Maps", keyword: "maps",
                  url: "https://www.google.com/maps/search/{query}"),
    ]

    public var takesQuery: Bool { url.range(of: Self.placeholder, options: .caseInsensitive) != nil }

    /// The keyword without surrounding spaces; nil when empty.
    var trimmedKeyword: String? {
        let trimmed = keyword?.trimmingCharacters(in: .whitespaces) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Every {query} replaced by `query`, percent-encoded; nil when the
    /// result does not parse as a URL with a scheme.
    public func url(for query: String) -> URL? {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: Self.unreserved) ?? ""
        let filled = url.replacingOccurrences(of: Self.placeholder, with: encoded, options: .caseInsensitive)
        // Strict parsing: the lenient default would quietly encode
        // "https://exa mple.com" into something that opens.
        guard let result = URL(string: filled, encodingInvalidCharacters: false),
              let scheme = result.scheme, !scheme.isEmpty
        else { return nil }
        return result
    }

    private static let placeholder = "{query}"
    /// Only these stay as they are; "&", "#", "?", "/", "+", "=" and spaces are encoded.
    private static let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
}

public enum Quicklinks {
    /// "gh dot launcher" → (GitHub, "dot launcher").
    public static func match(_ query: String, in links: [Quicklink]) -> (link: Quicklink, text: String)? {
        guard let space = query.firstIndex(where: \.isWhitespace) else { return nil }
        let word = query[..<space].lowercased()
        let text = query[space...].trimmingCharacters(in: .whitespaces)
        guard !word.isEmpty, !text.isEmpty,
              let link = links.first(where: { $0.takesQuery && $0.trimmedKeyword?.lowercased() == word })
        else { return nil }
        return (link, text)
    }

    /// The first problem with saving `draft` among `existing`, or nil.
    public static func problem(with draft: Quicklink, existing: [Quicklink]) -> String? {
        if draft.name.trimmingCharacters(in: .whitespaces).isEmpty { return "Add a name." }
        if let keyword = draft.trimmedKeyword {
            if keyword.contains(where: \.isWhitespace) { return "A keyword is one word, without spaces." }
            let taken = existing.contains { $0.id != draft.id && $0.trimmedKeyword?.lowercased() == keyword.lowercased() }
            if taken { return "Another quicklink uses this keyword." }
        }
        if draft.url(for: "test") == nil { return "Enter a full URL, such as https://example.com/search?q={query}." }
        return nil
    }
}
