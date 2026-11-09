import AppKit
import Observation

/// One row in the launcher list.
struct LauncherResult: Identifiable {
    enum Icon {
        case image(NSImage)
        case symbol(String)
    }

    enum Action {
        /// Hide the panel, then run.
        case run(() -> Void)
        /// Keep the panel open and switch to another mode.
        case enter(LauncherModel.Mode)
    }

    let id: String
    let title: String
    let subtitle: String
    let icon: Icon
    let accessory: String
    /// Footer label for ⏎, such as "Open" or "Copy".
    let actionTitle: String
    let action: Action
}

@Observable
final class LauncherModel {
    enum Mode: Equatable {
        case root
        case clipboard

        var placeholder: String {
            switch self {
            case .root: "Search apps, calculate, or run a command…"
            case .clipboard: "Search clipboard history…"
            }
        }
    }

    private(set) var mode = Mode.root
    var query = "" {
        didSet {
            guard query != oldValue else { return }
            refresh()
        }
    }
    private(set) var results: [LauncherResult] = []
    private(set) var selectedIndex = 0

    /// Root-mode results. Set by the composition root.
    @ObservationIgnored var search: (String) -> [LauncherResult] = { _ in [] }
    /// Clipboard-mode results, read from the store off the main actor.
    @ObservationIgnored var clipboardSearch: (String) async -> [LauncherResult] = { _ in [] }
    /// Hides the panel. Set by PanelController.
    @ObservationIgnored var close: () -> Void = {}
    /// The search field, so the panel can give it focus on every show.
    @ObservationIgnored weak var searchField: NSTextField?
    @ObservationIgnored private var clipboardTask: Task<Void, Never>?

    var selected: LauncherResult? {
        results.indices.contains(selectedIndex) ? results[selectedIndex] : nil
    }

    func reset(to mode: Mode = .root) {
        self.mode = mode
        searchField?.stringValue = ""
        if query.isEmpty {
            refresh()
        } else {
            query = ""
        }
    }

    func refresh() {
        switch mode {
        case .root:
            let started = ContinuousClock.now
            results = search(query)
            selectedIndex = 0
            let elapsed = started.duration(to: .now)
            // Debug level is never persisted; visible only with `make logs`.
            Log.panel.debug("query “\(self.query, privacy: .public)” → \(self.results.count) results, top: \(self.results.first?.title ?? "-", privacy: .public) in \(elapsed, privacy: .public)")
        case .clipboard:
            clipboardTask?.cancel()
            let query = query
            clipboardTask = Task {
                let found = await clipboardSearch(query)
                guard !Task.isCancelled, self.mode == .clipboard, self.query == query else { return }
                results = found
                selectedIndex = 0
            }
        }
    }

    func moveSelection(by delta: Int) {
        guard !results.isEmpty else { return }
        selectedIndex = min(max(selectedIndex + delta, 0), results.count - 1)
    }

    func select(index: Int) {
        guard results.indices.contains(index) else { return }
        selectedIndex = index
    }

    func performSelected() {
        guard let item = selected else { return }
        switch item.action {
        case .run(let work):
            close()
            work()
        case .enter(let mode):
            reset(to: mode)
        }
    }

    /// Esc leaves a sub-mode first, then closes the panel.
    func escape() {
        if mode == .root {
            close()
        } else {
            reset(to: .root)
        }
    }
}
