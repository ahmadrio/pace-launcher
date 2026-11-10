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
        case quicklink(Quicklink)
    }

    /// Snippets to rank in root search, and how to show one as a row.
    /// Set by the composition root.
    var snippets: () -> [Snippet] = { [] }
    var snippetRow: ((Snippet) -> LauncherResult)?
    var scripts: () -> [ScriptCommand] = { [] }
    var scriptRow: ((ScriptCommand) -> LauncherResult)?
    /// Exchange rates for currency conversions. Set by the composition root.
    var rates: RatesService?
    /// Saved URLs, how to open one (with the typed text, "" for none), and
    /// how to ask for the text of one that takes it.
    var quicklinks: () -> [Quicklink] = { [] }
    var openQuicklink: ((Quicklink, String) -> Void)?
    var enterQuicklink: ((Quicklink) -> Void)?

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
        for link in quicklinks() {
            let id = Self.usageID(of: link)
            candidates.append(Quicklinks.searchCandidate(for: link, id: id))
            items[id] = .quicklink(link)
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
        let calculation = conversion(for: query) ?? dateRow(for: query) ?? calculation(for: query)
        return [calculation, inlineQuicklink(for: query)].compactMap { $0 } + matches
            + [calculation == nil ? askAIRow(for: query) : nil].compactMap { $0 }
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
        let digits = ConversionFormat.currencyDigits(for: value)
        return conversionRow(
            title: ConversionFormat.display(value, maxFractionDigits: digits.maxFractionDigits, significantDigits: digits.significantDigits, locale: locale) + " " + to,
            subtitle: subtitle,
            copied: ConversionFormat.copy(value, maxFractionDigits: digits.maxFractionDigits, significantDigits: digits.significantDigits, locale: locale)
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

    /// "now + 3 days", "days until 17 aug", "time in tokyo".
    private func dateRow(for query: String) -> LauncherResult? {
        guard let result = DateQuery.evaluate(query, now: .now, timeZone: .current) else { return nil }
        let shown = DateQuery.display(result, locale: .current, timeZone: .current)
        let isTime = if case .time = result { true } else { false }
        return LauncherResult(
            id: "date",
            title: shown.title,
            subtitle: query.trimmingCharacters(in: .whitespaces),
            icon: .symbol(isTime ? "clock" : "calendar"),
            accessory: "Date",
            actionTitle: "Copy",
            action: .run {
                TextPaster.copy(shown.copy)
                Log.panel.info("copied a date result")
            }
        )
    }

    private func calculation(for query: String) -> LauncherResult? {
        guard let value = Calculator.evaluate(query) else { return nil }
        let separator = Locale.current.decimalSeparator ?? "."
        // Grouped for reading; copied without grouping so it pastes as a number.
        let formatted = Calculator.format(value, decimalSeparator: separator)
        return LauncherResult(
            id: "calc",
            title: Calculator.display(value, locale: .current),
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

    /// "gh dot launcher": search GitHub right away.
    private func inlineQuicklink(for query: String) -> LauncherResult? {
        guard let (link, text) = Quicklinks.match(query, in: quicklinks()) else { return nil }
        return LauncherResult(
            id: "quicklink-inline",
            title: "Search \(link.name) for “\(text)”",
            subtitle: Self.quicklinkSubtitle(for: link),
            icon: .symbol("link"),
            accessory: "Quicklink",
            actionTitle: "Open",
            action: .run { [weak self] in
                self?.recordUse(Self.usageID(of: link))
                self?.openQuicklink?(link, text)
            }
        )
    }

    private static func usageID(of link: Quicklink) -> String { "quicklink:" + link.id.uuidString }

    /// "gh · github.com".
    static func quicklinkSubtitle(for link: Quicklink) -> String {
        [link.keyword, link.displayHost].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func result(for item: Item, id: String) -> LauncherResult? {
        switch item {
        case .quicklink(let link):
            let action: LauncherResult.Action = link.takesQuery
                ? .stay { [weak self] in self?.enterQuicklink?(link) }
                : .run { [weak self] in self?.openQuicklink?(link, "") }
            return LauncherResult(
                id: id, title: link.name, subtitle: Self.quicklinkSubtitle(for: link), icon: .symbol("link"),
                accessory: "Quicklink", actionTitle: link.takesQuery ? "Search" : "Open",
                action: recordingUse(of: id, action)
            )
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
                action: command.recordsUse ? recordingUse(of: id, command.action) : command.action
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
