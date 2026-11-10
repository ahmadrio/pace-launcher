import Foundation

/// Daily exchange rates against one base currency, as cached on disk.
public struct ExchangeRates: Sendable, Equatable, Codable {
    public let base: String
    /// Units of each currency per one unit of `base`.
    public let rates: [String: Double]
    /// When the provider last updated the rates.
    public let updated: Date
    /// When PACE downloaded them (drives the 12-hour refresh).
    public let fetchedAt: Date

    public init(base: String, rates: [String: Double], updated: Date, fetchedAt: Date) {
        self.base = base
        self.rates = rates
        self.updated = updated
        self.fetchedAt = fetchedAt
    }

    /// The fields of an open.er-api.com v6 "latest" response.
    private struct Response: Decodable {
        let result: String
        let base_code: String
        let time_last_update_unix: Double
        let rates: [String: Double]
    }

    /// Reads an open.er-api.com v6 response; nil unless it succeeded.
    public static func decode(_ data: Data, fetchedAt: Date) -> ExchangeRates? {
        guard let response = try? JSONDecoder().decode(Response.self, from: data),
              response.result == "success", !response.rates.isEmpty
        else { return nil }
        return ExchangeRates(
            base: response.base_code, rates: response.rates,
            updated: Date(timeIntervalSince1970: response.time_last_update_unix), fetchedAt: fetchedAt
        )
    }

    /// Converts through the base currency; nil for unknown codes.
    public func convert(_ amount: Double, from: String, to: String) -> Double? {
        guard let fromRate = rates[from], let toRate = rates[to], fromRate > 0 else { return nil }
        return amount / fromRate * toRate
    }

    /// Downloaded more than 12 hours ago.
    public func needsRefresh(now: Date) -> Bool {
        now.timeIntervalSince(fetchedAt) > 12 * 3600
    }

    /// The provider's rates are more than a week old (e.g. offline).
    public func isOutdated(now: Date) -> Bool {
        now.timeIntervalSince(updated) > 7 * 86_400
    }

    public func knows(_ code: String) -> Bool { rates[code] != nil }
}
