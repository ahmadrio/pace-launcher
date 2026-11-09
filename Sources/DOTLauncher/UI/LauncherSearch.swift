import AppKit
import DOTLauncherCore

/// Turns a root-mode query into launcher rows by ranking apps and commands.
final class LauncherSearch {
    private enum Item {
        case app(AppEntry)
        case command(LauncherCommand)
    }

    private let indexer: AppIndexer
    private let usage: UsageStore?
    private let icons: IconCache
    private let commands: [LauncherCommand]

    private var candidates: [SearchCandidate<String>] = []
    private var items: [String: Item] = [:]

    init(indexer: AppIndexer, usage: UsageStore?, icons: IconCache, commands: [LauncherCommand]) {
        self.indexer = indexer
        self.usage = usage
        self.icons = icons
        self.commands = commands
        rebuild()
    }

    /// Rebuilds the prepared candidates after the app index changes.
    func rebuild() {
        var candidates: [SearchCandidate<String>] = []
        var items: [String: Item] = [:]
        for command in commands {
            candidates.append(SearchCandidate(id: command.usageID, title: command.title, aliases: command.aliases))
            items[command.usageID] = .command(command)
        }
        for app in indexer.apps {
            let id = app.usageID
            candidates.append(SearchCandidate(id: id, title: app.name, aliases: app.aliases))
            items[id] = .app(app)
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
            items[id].map { result(for: $0, id: id) }
        }
        // A calculation is always the first row.
        return [calculation(for: query)].compactMap { $0 } + matches
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
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(formatted, forType: .string)
                Log.panel.info("copied calculator result")
            }
        )
    }

    private func result(for item: Item, id: String) -> LauncherResult {
        switch item {
        case .app(let app):
            LauncherResult(
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
            LauncherResult(
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
