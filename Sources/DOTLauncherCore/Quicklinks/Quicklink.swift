import CryptoKit
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

    /// A stable id for an entry written without one (settings.json by hand):
    /// the same name and URL always give the same id.
    public static func derivedID(name: String, url: String) -> UUID {
        var bytes = Array(SHA256.hash(data: Data((name + "\n" + url).utf8)).prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50  // version 5 (name-based)
        bytes[8] = (bytes[8] & 0x3F) | 0x80  // RFC 4122 variant
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }

    private enum CodingKeys: String, CodingKey { case id, name, keyword, url }

    /// A missing id (an entry written by hand) gets `derivedID`, so the entry
    /// is kept and keeps the same id every time it is read.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        url = try container.decode(String.self, forKey: .url)
        keyword = try container.decodeIfPresent(String.self, forKey: .keyword)
        // A hand-written id that is not a UUID ("wiki") counts as no id.
        id = (try? container.decodeIfPresent(UUID.self, forKey: .id)) ?? Self.derivedID(name: name, url: url)
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

    /// The host for showing ("bücher.de", not its encoded form).
    public var displayHost: String? {
        // From the template as typed: the built URL holds punycode (xn--…),
        // while this keeps "bücher.de", only percent-encoded.
        let marked = url.replacingOccurrences(of: Self.placeholder, with: Self.marker, options: .caseInsensitive)
        guard let host = URL(string: marked)?.host(), !host.isEmpty else { return nil }
        // "{query}.slack.com" stays readable; the marker is internal.
        return (host.removingPercentEncoding ?? host).replacingOccurrences(of: Self.marker, with: Self.placeholder)
    }

    public var takesQuery: Bool { url.range(of: Self.placeholder, options: .caseInsensitive) != nil }

    /// The keyword without surrounding spaces; nil when empty.
    var trimmedKeyword: String? {
        let trimmed = keyword?.trimmingCharacters(in: .whitespaces) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Every {query} replaced by `query`, percent-encoded; nil when the
    /// result does not parse as a URL with a scheme.
    public func url(for query: String) -> URL? {
        // Spaces mean a typo ("https://exa mple.com"); anything else Foundation
        // can make valid: "bücher.de" becomes punycode, "ø" and "|" are encoded.
        guard !url.contains(where: \.isWhitespace) else { return nil }
        // Normalize the template with a plain marker where the text goes, then
        // insert the encoded text: normalizing after inserting would encode
        // its "%" again ("a b" → "a%2520b").
        let marked = url.replacingOccurrences(of: Self.placeholder, with: Self.marker, options: .caseInsensitive)
        guard let normalized = URL(string: marked)?.absoluteString else { return nil }
        let encoded = query.addingPercentEncoding(withAllowedCharacters: Self.unreserved) ?? ""
        let filled = normalized.replacingOccurrences(of: Self.marker, with: encoded)
        guard let result = URL(string: filled, encodingInvalidCharacters: false),
              let scheme = result.scheme, !scheme.isEmpty
        else { return nil }
        return result
    }

    private static let placeholder = "{query}"
    /// Lowercase ASCII letters and digits only, so normalizing leaves it alone.
    private static let marker = "dotlauncherquery7f3a"
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

    /// How a quicklink ranks in root search: by its name only. The keyword
    /// acts through "<keyword> <text>", so typing "g" alone still finds the
    /// app it usually finds.
    public static func searchCandidate(for link: Quicklink, id: String) -> SearchCandidate<String> {
        SearchCandidate(id: id, title: link.name)
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
