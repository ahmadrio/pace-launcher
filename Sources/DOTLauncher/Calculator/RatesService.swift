import DOTLauncherCore
import Foundation
import Observation

/// Exchange rates for currency conversions: read from a local cache and
/// downloaded only when a currency conversion is on screen and the cache
/// is missing or older than 12 hours. Nothing about the user is sent.
@Observable
final class RatesService {
    static let defaultURL = URL(string: "https://open.er-api.com/v6/latest/USD")!

    private(set) var rates: ExchangeRates?
    private(set) var isFetching = false

    /// Called after every download attempt, so visible rows can update.
    @ObservationIgnored var onUpdate: (() -> Void)?
    @ObservationIgnored private let file: URL
    @ObservationIgnored private let url: URL
    @ObservationIgnored private var lastAttempt: Date?

    init(file: URL = AppPaths.exchangeRatesFile) {
        self.file = file
        // Test hook, like DOTDataRootOverride: point at an unreachable URL
        // to see the offline row.
        let override = UserDefaults.standard.string(forKey: "DOTRatesURLOverride").flatMap(URL.init(string:))
        url = override ?? Self.defaultURL
        rates = (try? Data(contentsOf: file)).flatMap { try? JSONDecoder().decode(ExchangeRates.self, from: $0) }
    }

    /// Starts a download when the rates are missing or stale. Typing calls
    /// this on every key, so one runs at a time and a failure waits a minute.
    func refreshIfNeeded() {
        guard !isFetching else { return }
        if let rates, !rates.needsRefresh(now: .now) { return }
        if let lastAttempt, Date.now.timeIntervalSince(lastAttempt) < 60 { return }
        start()
    }

    /// Tries again now (the "unavailable" row's action).
    func retry() {
        guard !isFetching else { return }
        start()
    }

    private func start() {
        isFetching = true
        lastAttempt = .now
        Task { await fetch() }
    }

    private func fetch() async {
        defer {
            isFetching = false
            onUpdate?()
        }
        do {
            let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let fresh = ExchangeRates.decode(data, fetchedAt: .now)
            else {
                Log.app.notice("exchange rates download returned an unexpected response")
                return
            }
            rates = fresh
            do {
                try JSONEncoder().encode(fresh).write(to: file, options: .atomic)
            } catch {
                Log.app.error("could not cache exchange rates: \(error.localizedDescription, privacy: .public)")
            }
            Log.app.info("exchange rates updated (\(fresh.rates.count) currencies)")
        } catch {
            Log.app.notice("exchange rates download failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
