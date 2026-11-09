import AppKit
import DOTLauncherCore

/// The snippets on disk, cached for search, plus the actions on them.
final class SnippetLibrary {
    private var store: SnippetStore
    private(set) var snippets: [Snippet] = []
    /// Called after every change, so search can rebuild its candidates.
    var onChange: (() -> Void)?

    init(store: SnippetStore) {
        self.store = store
        reload()
    }

    /// Points the library at another folder (sync turned on or off).
    func switchStore(_ store: SnippetStore) {
        self.store = store
        reload()
    }

    func reload() {
        do {
            snippets = try store.all()
        } catch {
            Log.app.error("could not read snippets: \(String(describing: error), privacy: .public)")
        }
        onChange?()
    }

    func save(_ snippet: Snippet) {
        do {
            try store.save(snippet)
        } catch {
            Log.app.error("could not save snippet: \(String(describing: error), privacy: .public)")
        }
        reload()
    }

    func delete(_ id: UUID) {
        do {
            try store.delete(id: id)
        } catch {
            Log.app.error("could not delete snippet: \(String(describing: error), privacy: .public)")
        }
        reload()
    }

    /// Expands placeholders with the current clipboard, then pastes
    /// temporarily (the clipboard is restored afterwards).
    func paste(_ snippet: Snippet, monitor: PasteboardMonitor?) {
        let clipboard = NSPasteboard.general.string(forType: .string)
        let text = SnippetExpander.expand(snippet.content, now: .now, clipboard: clipboard)
        TextPaster.paste(text, monitor: monitor)
    }

    /// All snippets for an empty query; otherwise name/keyword fuzzy
    /// matches (best first), then snippets whose content contains the query.
    func search(_ query: String) -> [Snippet] {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return snippets }

        let byName = snippets
            .compactMap { snippet -> (Snippet, Double)? in
                let targets = [snippet.name] + [snippet.keyword].compactMap { $0 }
                let score = targets.compactMap { FuzzyMatcher.score(query, in: $0) }.max()
                return score.map { (snippet, $0) }
            }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
        let named = Set(byName.map(\.id))
        let byContent = snippets.filter {
            !named.contains($0.id) && $0.content.localizedCaseInsensitiveContains(query)
        }
        return byName + byContent
    }
}
