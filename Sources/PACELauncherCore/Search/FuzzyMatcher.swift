import Foundation

/// A candidate string prepared once for repeated fuzzy matching:
/// case- and diacritic-folded characters plus word-start positions.
public struct FuzzyTarget: Sendable {
    let characters: [Character]
    let wordStarts: [Bool]

    public init(_ text: String) {
        let original = Array(text)
        var characters: [Character] = []
        var wordStarts: [Bool] = []
        characters.reserveCapacity(original.count)
        wordStarts.reserveCapacity(original.count)

        for (index, character) in original.enumerated() {
            characters.append(Self.fold(character))
            guard index > 0 else {
                wordStarts.append(true)
                continue
            }
            let previous = original[index - 1]
            let isAlphanumeric = character.isLetter || character.isNumber
            let afterSeparator = !(previous.isLetter || previous.isNumber) && isAlphanumeric
            let camelHump = previous.isLowercase && character.isUppercase
            let digitAfterLetter = previous.isLetter && character.isNumber
            wordStarts.append(afterSeparator || camelHump || digitAfterLetter)
        }

        self.characters = characters
        self.wordStarts = wordStarts
    }

    static func fold(_ character: Character) -> Character {
        String(character)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .lowercased()
            .first ?? character
    }
}

/// Subsequence fuzzy matching with bonuses for word starts, consecutive
/// runs, prefixes and exact matches. Higher scores are better.
public enum FuzzyMatcher {
    private static let wordStartBonus = 8.0
    private static let firstCharacterBonus = 3.0
    private static let consecutiveBonus = 6.0
    private static let gapPenalty = 0.3
    private static let leadingPenalty = 0.15
    private static let maxLeadingPenalty = 3.0
    private static let prefixBonus = 20.0
    private static let exactBonus = 50.0
    private static let lengthPenalty = 0.05

    /// Returns nil when `query` is not a subsequence of the target.
    /// An empty query matches everything with a score of 0.
    public static func score(_ query: String, in target: FuzzyTarget) -> Double? {
        let query = query.map(FuzzyTarget.fold)
        let text = target.characters
        let m = query.count
        let n = text.count
        guard m > 0 else { return 0 }
        guard m <= n else { return nil }

        // previous[j]: best score with the previous query character matched at text[j].
        var previous = [Double](repeating: -.infinity, count: n)
        for j in 0..<n where text[j] == query[0] {
            let leading = min(Double(j) * leadingPenalty, maxLeadingPenalty)
            previous[j] = characterScore(target, j) + (j == 0 ? firstCharacterBonus : 0) - leading
        }

        for i in 1..<m {
            var current = [Double](repeating: -.infinity, count: n)
            // best[k] - gap * skipped, over every k at least two positions back.
            var gapped = -Double.infinity
            for j in 1..<n {
                if j >= 2 {
                    gapped = max(gapped - gapPenalty, previous[j - 2] - gapPenalty)
                }
                guard text[j] == query[i] else { continue }
                let viaRun = previous[j - 1] + consecutiveBonus
                let best = max(viaRun, gapped)
                if best > -.infinity {
                    current[j] = best + characterScore(target, j)
                }
            }
            previous = current
        }

        guard var result = previous.max(), result > -.infinity else { return nil }
        if text.starts(with: query) {
            result += prefixBonus
            if m == n { result += exactBonus }
        }
        return result - Double(n - m) * lengthPenalty
    }

    public static func score(_ query: String, in candidate: String) -> Double? {
        score(query, in: FuzzyTarget(candidate))
    }

    private static func characterScore(_ target: FuzzyTarget, _ index: Int) -> Double {
        1 + (target.wordStarts[index] ? wordStartBonus : 0)
    }
}
