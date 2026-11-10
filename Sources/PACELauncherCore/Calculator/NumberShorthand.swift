/// Words that scale the number before them: "10k", "1,5jt", "1 juta".
public enum NumberShorthand {
    private static let multipliers: [String: Double] = [
        "k": 1e3, "rb": 1e3, "ribu": 1e3, "thousand": 1e3,
        "jt": 1e6, "juta": 1e6, "million": 1e6,
        "miliar": 1e9, "milyar": 1e9, "billion": 1e9,
        "triliun": 1e12, "trillion": 1e12,
    ]

    /// k, rb, ribu, thousand → 1e3; jt, juta, million → 1e6; miliar, milyar,
    /// billion → 1e9; triliun, trillion → 1e12. Case-insensitive; nil for
    /// anything else.
    public static func multiplier(for word: some StringProtocol) -> Double? {
        multipliers[word.lowercased()]
    }

    /// "1,5jt" → ("1,5", 1e6), "1 juta" → ("1", 1e6). Nil unless `text` is a
    /// number part followed by one shorthand word that ends the text.
    static func split(_ text: String) -> (number: String, multiplier: Double)? {
        let word = text.reversed().prefix { $0.isLetter }
        guard !word.isEmpty, let multiplier = multiplier(for: String(word.reversed())) else { return nil }
        let number = text.dropLast(word.count).trimmingSuffix { $0.isWhitespace }
        guard let last = number.last, last.isNumber else { return nil }
        return (String(number), multiplier)
    }
}

private extension Substring {
    func trimmingSuffix(while predicate: (Character) -> Bool) -> Substring {
        var result = self
        while let last = result.last, predicate(last) { result.removeLast() }
        return result
    }
}
