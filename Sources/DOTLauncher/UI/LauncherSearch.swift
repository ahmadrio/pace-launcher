import AppKit
import DOTLauncherCore

/// Turns a query into launcher rows by ranking every searchable item.
final class LauncherSearch {
    private enum Item {
        case app(AppEntry)
    }

    private let indexer: AppIndexer
    private let usage: UsageStore?
    private let icons = IconCache()

    private var candidates: [SearchCandidate<String>] = []
    private var items: [String: Item] = [:]

    init(indexer: AppIndexer, usage: UsageStore?) {
        self.indexer = indexer
        self.usage = usage
    }

    /// Rebuilds the prepared candidates after the app index changes.
    func rebuild() {
        var candidates: [SearchCandidate<String>] = []
        var items: [String: Item] = [:]
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
        return ResultRanker.rank(query, ranked, limit: 30).compactMap { id in
            items[id].map { result(for: $0, id: id) }
        }
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
                perform: { [weak self] in
                    self?.recordUse(id)
                    AppLauncher.open(app)
                }
            )
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
