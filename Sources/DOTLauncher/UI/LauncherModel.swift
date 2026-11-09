import AppKit
import Observation

/// One row in the launcher list.
struct LauncherResult: Identifiable {
    enum Icon {
        case image(NSImage)
        case symbol(String)
    }

    let id: String
    let title: String
    let subtitle: String
    let icon: Icon
    let accessory: String
    /// What ⏎ does. Runs after the panel has been hidden.
    let perform: () -> Void
}

@Observable
final class LauncherModel {
    var query = "" {
        didSet {
            guard query != oldValue else { return }
            refresh()
        }
    }
    private(set) var results: [LauncherResult] = []
    private(set) var selectedIndex = 0
    /// Short feedback shown in the footer, such as "Copied".
    var toast: String?

    /// Produces results for a query. Set by the composition root.
    @ObservationIgnored var search: (String) -> [LauncherResult] = { _ in [] }
    /// Hides the panel. Set by PanelController.
    @ObservationIgnored var close: () -> Void = {}
    /// The search field, so the panel can give it focus on every show.
    @ObservationIgnored weak var searchField: NSTextField?

    var selected: LauncherResult? {
        results.indices.contains(selectedIndex) ? results[selectedIndex] : nil
    }

    func reset() {
        toast = nil
        if query.isEmpty {
            refresh()
        } else {
            query = ""
        }
        searchField?.stringValue = ""
    }

    func refresh() {
        results = search(query)
        selectedIndex = 0
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
        close()
        item.perform()
    }
}
