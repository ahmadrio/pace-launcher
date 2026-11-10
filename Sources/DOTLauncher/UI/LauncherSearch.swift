import AppKit
import DOTLauncherCore

/// Turns a root-mode query into launcher rows by ranking apps, commands
/// and snippets.
final class LauncherSearch {
    private enum Item {
        case app(AppEntry)
        case command(LauncherCommand)
        case snippet(Snippet)
        case script(ScriptCommand)
    }

    /// Snippets to rank in root search, and how to show one as a row.
    /// Set by the composition root.
    var snippets: () -> [Snippet] = { [] }
    var snippetRow: ((Snippet) -> LauncherResult)?
    var scripts: () -> [ScriptCommand] = { [] }
    var scriptRow: ((ScriptCommand) -> LauncherResult)?
    /// Exchange rates for currency conversions. Set by the composition root.
    var rates: RatesService?

    private let indexer: AppIndexer
    private let usage: UsageStore?
    private let icons: IconCache
    /// Evaluated on every rebuild, so subtitles that show state stay fresh.
    private let commands: () -> [LauncherCommand]

    private var candidates: [SearchCandidate<String>] = []
    private var items: [String: Item] = [:]

    init(indexer: AppIndexer, usage: UsageStore?, icons: IconCache, commands: @escaping () -> [LauncherCommand]) {
        self.indexer = indexer
        self.usage = usage
        self.icons = icons
        self.commands = commands
        rebuild()
    }

    /// Rebuilds the prepared candidates (after the app index changes, and
    /// on every panel open so command subtitles reflect current state).
    func rebuild() {
        var candidates: [SearchCandidate<String>] = []
        var items: [String: Item] = [:]
        for command in commands() {
            candidates.append(SearchCandidate(id: command.usageID, title: command.title, aliases: command.aliases))
            items[command.usageID] = .command(command)
        }
        for app in indexer.apps {
            let id = app.usageID
            candidates.append(SearchCandidate(id: id, title: app.name, aliases: app.aliases))
            items[id] = .app(app)
        }
        for script in scripts() {
            let id = "script:" + script.id
            candidates.append(SearchCandidate(id: id, title: script.metadata.title, aliases: [script.metadata.packageName].compactMap { $0 }))
            items[id] = .script(script)
        }
        for snippet in snippets() {
            let id = "snippet:" + snippet.id.uuidString
            candidates.append(SearchCandidate(id: id, title: snippet.name, aliases: [snippet.keyword].compactMap { $0 }))
            items[id] = .snippet(snippet)
        }
        self.candidates = candidates
        self.items = items
    }

    func results(for query: String) -> [LauncherResult] {
        let now = Date.now
        var ranked = candidates
        for index in ranked.indices {
            ranked[index].frecency = usage?.frecency(for: ranked[index].id, now: now) ?? 0
        }
        let matches = ResultRanker.rank(query, ranked, limit: 30).compactMap { id in
            items[id].flatMap { result(for: $0, id: id) }
        }
        // A conversion or calculation is always the first row; "Ask AI" is
        // always the last.
        let calculation = conversion(for: query) ?? calculation(for: query)
        return [calculation].compactMap { $0 } + matches + [calculation == nil ? askAIRow(for: query) : nil].compactMap { $0 }
    }

    /// Sends a root query to AI Chat. Set by the composition root.
    var askAI: ((String) -> Void)?

    private func askAIRow(for query: String) -> LauncherResult? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2, let askAI else { return nil }
        return LauncherResult(
            id: "ask-ai",
            title: "Ask AI",
            subtitle: trimmed,
            icon: .symbol("sparkles"),
            accessory: "Tab",
            actionTitle: "Ask",
            action: .stay { askAI(trimmed) }
        )
    }

    private static let ratesDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    /// "10 km to mi", "100 usd to idr", "$25".
    private func conversion(for query: String) -> LauncherResult? {
        guard let parsed = Converter.parse(query) else { return nil }
        let locale = Locale.current
        let trimmed = query.trimmingCharacters(in: .whitespaces)

        if case .unit = parsed.from {
            guard let value = Converter.convertUnits(parsed), case .unit(let to)? = parsed.to else { return nil }
            let copied = ConversionFormat.copy(value, maxFractionDigits: nil, significantDigits: 6, locale: locale)
            return conversionRow(
                title: ConversionFormat.display(value, maxFractionDigits: nil, significantDigits: 6, locale: locale) + " " + to.symbol,
                subtitle: trimmed, copied: copied
            )
        }

        let conversion = Converter.resolveCurrencyTarget(parsed, localCurrency: locale.currency?.identifier)
        guard case .currency(let from) = conversion.from, case .currency(let to)? = conversion.to, let service = rates else { return nil }
        service.refreshIfNeeded()
        guard let current = service.rates else {
            return LauncherResult(
                id: "convert",
                title: service.isFetching ? "Fetching exchange rates…" : "Exchange rates unavailable (offline?)",
                subtitle: service.isFetching ? "\(trimmed) · from ExchangeRate-API" : "Press Return to try again",
                icon: .symbol("dollarsign.arrow.circlepath"),
                accessory: "Convert",
                actionTitle: service.isFetching ? "" : "Retry",
                action: .stay { service.retry() }
            )
        }
        guard let value = current.convert(conversion.amount, from: from, to: to) else { return nil }
        var subtitle = "\(trimmed) · Rates by ExchangeRate-API · \(Self.ratesDate.string(from: current.updated))"
        if current.isOutdated(now: .now) { subtitle += " · rates may be outdated" }
        return conversionRow(
            title: ConversionFormat.display(value, maxFractionDigits: 2, significantDigits: nil, locale: locale) + " " + to,
            subtitle: subtitle,
            copied: ConversionFormat.copy(value, maxFractionDigits: 2, significantDigits: nil, locale: locale)
        )
    }

    private func conversionRow(title: String, subtitle: String, copied: String) -> LauncherResult {
        LauncherResult(
            id: "convert",
            title: title,
            subtitle: subtitle,
            icon: .symbol("arrow.left.arrow.right"),
            accessory: "Convert",
            actionTitle: "Copy",
            action: .run {
                TextPaster.copy(copied)
                Log.panel.info("copied a conversion result")
            }
        )
    }

    private func calculation(for query: String) -> LauncherResult? {
        guard let value = Calculator.evaluate(query) else { return nil }
        let separator = Locale.current.decimalSeparator ?? "."
        let formatted = Calculator.format(value, decimalSeparator: separator)
        return LauncherResult(
            id: "calc",
            title: formatted,
            subtitle: query.trimmingCharacters(in: .whitespaces),
            icon: .symbol("equal"),
            accessory: "Calculator",
            actionTitle: "Copy",
            action: .run {
                TextPaster.copy(formatted)
                Log.panel.info("copied calculator result")
            }
        )
    }

    private func result(for item: Item, id: String) -> LauncherResult? {
        switch item {
        case .script(let script):
            guard let row = scriptRow?(script) else { return nil }
            return LauncherResult(
                id: id, title: row.title, subtitle: row.subtitle, icon: row.icon, accessory: row.accessory,
                actionTitle: row.actionTitle, action: recordingUse(of: id, row.action),
                secondaryActions: row.secondaryActions
            )
        case .snippet(let snippet):
            guard let row = snippetRow?(snippet) else { return nil }
            // Same row, keyed for root ranking and learning frecency.
            return LauncherResult(
                id: id, title: row.title, subtitle: row.subtitle, icon: row.icon, accessory: row.accessory,
                actionTitle: row.actionTitle, action: recordingUse(of: id, row.action),
                secondaryActions: row.secondaryActions
            )
        case .app(let app):
            return LauncherResult(
                id: id,
                title: app.name,
                subtitle: Self.folderName(of: app.path),
                icon: .image(icons.icon(forPath: app.path)),
                accessory: "Application",
                actionTitle: "Open",
                action: .run { [weak self] in
                    self?.recordUse(id)
                    AppLauncher.open(app)
                }
            )
        case .command(let command):
            return LauncherResult(
                id: id,
                title: command.title,
                subtitle: command.subtitle,
                icon: .symbol(command.symbol),
                accessory: "Command",
                actionTitle: command.actionTitle,
                action: recordingUse(of: id, command.action)
            )
        }
    }

    /// Records usage before running, so commands learn frecency too.
    private func recordingUse(of id: String, _ action: LauncherResult.Action) -> LauncherResult.Action {
        switch action {
        case .run(let work):
            .run { [weak self] in
                self?.recordUse(id)
                work()
            }
        case .stay(let work):
            .stay { [weak self] in
                self?.recordUse(id)
                work()
            }
        case .enter:
            // Mode switches are cheap to reach again; usage is recorded
            // only for commands that do something.
            action
        }
    }

    private func recordUse(_ id: String) {
        do {
            try usage?.recordUse(of: id)
        } catch {
            Log.apps.error("could not record usage: \(String(describing: error), privacy: .public)")
        }
    }

    private static func folderName(of path: String) -> String {
        let folder = (path as NSString).deletingLastPathComponent
        return (folder as NSString).abbreviatingWithTildeInPath
    }
}
