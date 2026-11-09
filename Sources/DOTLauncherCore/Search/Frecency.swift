import Foundation

/// Frequency weighted by recency: each use counts for less as it ages.
public enum Frecency {
    public static let halfLife: TimeInterval = 14 * 86_400

    public static func score(count: Int, lastUsed: Date, now: Date) -> Double {
        guard count > 0 else { return 0 }
        let age = max(0, now.timeIntervalSince(lastUsed))
        return Double(count) * pow(0.5, age / halfLife)
    }
}
