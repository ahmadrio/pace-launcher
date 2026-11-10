import Foundation

/// How long unpinned clips are kept (Settings › General).
public enum ClipboardRetention: String, Codable, Sendable, CaseIterable {
    case forever, year, sixMonths, threeMonths, month, week, day

    public var title: String {
        switch self {
        case .forever: "Forever"
        case .year: "1 year"
        case .sixMonths: "6 months"
        case .threeMonths: "3 months"
        case .month: "1 month"
        case .week: "1 week"
        case .day: "1 day"
        }
    }

    /// Clips last used before this date are removed; nil keeps everything.
    public func cutoff(now: Date, calendar: Calendar = .current) -> Date? {
        switch self {
        case .forever: nil
        case .year: calendar.date(byAdding: .year, value: -1, to: now)
        case .sixMonths: calendar.date(byAdding: .month, value: -6, to: now)
        case .threeMonths: calendar.date(byAdding: .month, value: -3, to: now)
        case .month: calendar.date(byAdding: .month, value: -1, to: now)
        case .week: calendar.date(byAdding: .day, value: -7, to: now)
        case .day: calendar.date(byAdding: .day, value: -1, to: now)
        }
    }
}
