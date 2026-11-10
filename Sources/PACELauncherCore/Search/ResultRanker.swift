import Foundation

/// Something the launcher can find: a title, optional aliases, and how
/// often and recently it was used.
public struct SearchCandidate<ID: Hashable & Sendable>: Sendable {
    public let id: ID
    public let title: String
    public let targets: [FuzzyTarget]
    public var frecency: Double

    public init(id: ID, title: String, aliases: [String] = [], frecency: Double = 0) {
        self.id = id
        self.title = title
        self.targets = ([title] + aliases).map(FuzzyTarget.init)
        self.frecency = frecency
    }
}

public enum ResultRanker {
    /// How much usage history can lift a result. log1p keeps heavy use
    /// from burying a clearly better text match.
    static let frecencyWeight = 5.0

    /// Ranks candidates for `query`. An empty query lists only items that
    /// have been used, most frecent first.
    public static func rank<ID>(_ query: String, _ candidates: [SearchCandidate<ID>], limit: Int) -> [ID] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)

        let scored: [(candidate: SearchCandidate<ID>, score: Double)]
        if trimmed.isEmpty {
            scored = candidates.filter { $0.frecency > 0 }.map { ($0, $0.frecency) }
        } else {
            scored = candidates.compactMap { candidate in
                let match = candidate.targets.compactMap { FuzzyMatcher.score(trimmed, in: $0) }.max()
                return match.map { (candidate, $0 + frecencyWeight * log1p(candidate.frecency)) }
            }
        }

        return scored
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                return lhs.candidate.title.localizedStandardCompare(rhs.candidate.title) == .orderedAscending
            }
            .prefix(limit)
            .map(\.candidate.id)
    }
}
