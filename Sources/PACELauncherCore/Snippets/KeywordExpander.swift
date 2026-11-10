/// Watches typed text for snippet keywords. Feed it characters as they are
/// typed; it reports a keyword the moment the text ends with one.
public struct KeywordExpander {
    private let keywords: [String]
    private let capacity: Int
    private var buffer = ""

    public init(keywords: [String], capacity: Int = 64) {
        // Longest first, so "x;addr" matches ";addr" rather than "addr".
        self.keywords = keywords.filter { !$0.isEmpty }.sorted { $0.count > $1.count }
        self.capacity = max(capacity, self.keywords.first?.count ?? 1)
    }

    /// Adds typed text and returns the keyword that just completed, if any.
    /// The buffer is cleared after a match.
    public mutating func type(_ text: String) -> String? {
        buffer += text
        if buffer.count > capacity {
            buffer = String(buffer.suffix(capacity))
        }
        guard let match = keywords.first(where: { buffer.hasSuffix($0) }) else { return nil }
        buffer = ""
        return match
    }

    public mutating func deleteBackward() {
        if !buffer.isEmpty { buffer.removeLast() }
    }

    public mutating func reset() {
        buffer = ""
    }
}
