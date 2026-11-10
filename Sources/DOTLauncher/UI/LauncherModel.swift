import AppKit
import DOTLauncherCore
import Observation
import SwiftUI

/// One row in the launcher list.
struct LauncherResult: Identifiable {
    enum Icon {
        case image(NSImage)
        case symbol(String)
        /// An emoji or a short glyph.
        case text(String)
    }

    enum Action {
        /// Hide the panel, then run.
        case run(() -> Void)
        /// Run and keep the panel open (swap, new chat, delete…).
        case stay(() -> Void)
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
    var secondaryActions: [SecondaryAction] = []
}

@Observable
final class LauncherModel {
    enum Mode: Equatable, Hashable {
        case root
        case clipboard
        case translate
        case ai
        case chatHistory
        case snippets
        case notes
        case scriptOutput
        case scriptArguments
        case quicklink
        case emoji

        var placeholder: String {
            switch self {
            case .root: "Search apps, calculate, or run a command…"
            case .clipboard: "Search clipboard history…"
            case .translate: "Translate…"
            case .ai: "Ask anything…"
            case .chatHistory: "Search AI chats…"
            case .snippets: "Search snippets…"
            case .notes: "Search notes…"
            case .scriptOutput: "Script output"
            case .scriptArguments: "Fill in the arguments below"
            case .quicklink: "Type what to search for…"
            case .emoji: "Search emoji…"
            }
        }

        var title: String {
            switch self {
            case .root: "DOT Launcher"
            case .clipboard: "Clipboard History"
            case .translate: "Translate"
            case .ai: "AI Chat"
            case .chatHistory: "AI Chats"
            case .snippets: "Snippets"
            case .notes: "Notes"
            case .scriptOutput: "Script"
            case .scriptArguments: "Script"
            case .quicklink: "Quicklink"
            case .emoji: "Emoji"
            }
        }
    }

    /// How a mode other than root behaves.
    struct ModeHandler {
        /// Rows for list modes, fetched off the main actor when needed.
        var results: ((String) async -> [LauncherResult])?
        /// ⏎ when the mode has no rows to act on (translate, AI).
        var submit: (() -> Void)?
        var submitTitle = ""
        var actions: () -> [SecondaryAction] = { [] }
        /// Custom modes react to typing themselves instead of listing rows.
        var queryChanged: ((String) -> Void)?
        /// Returns true when it consumed Esc (for example to stop generating).
        var escape: (() -> Bool)?
        /// Called when the mode is entered.
        var entered: (() -> Void)?
        /// Details of the selected row, shown beside the list.
        var preview: ((LauncherResult) -> AnyView?)?
    }

    private(set) var mode = Mode.root
    var query = "" {
        didSet {
            guard query != oldValue else { return }
            notice = nil
            confirmation.reset()
            if let queryChanged = handlers[mode]?.queryChanged {
                queryChanged(query)
            } else {
                refresh()
            }
        }
    }
    private(set) var results: [LauncherResult] = []
    private(set) var selectedIndex = 0
    /// A one-line message in the footer, such as "Press ⌃X again to delete".
    var notice: String?

    /// Root-mode results. Set by the composition root.
    @ObservationIgnored var search: (String) -> [LauncherResult] = { _ in [] }
    @ObservationIgnored var handlers: [Mode: ModeHandler] = [:]
    /// Views that replace the result list in custom modes (translate, AI).
    @ObservationIgnored var customContent: [Mode: () -> AnyView] = [:]
    /// Hides the panel. Set by PanelController.
    @ObservationIgnored var close: () -> Void = {}
    /// Tab in the search field. Set by the composition root.
    @ObservationIgnored var onTab: (() -> Void)?
    /// The search field, so the panel can give it focus on every show.
    @ObservationIgnored weak var searchField: NSTextField?
    @ObservationIgnored private var listTask: Task<Void, Never>?
    /// The row to select again after the next refresh (set by `.stay`).
    @ObservationIgnored private var keepSelectionID: String?
    @ObservationIgnored private var confirmation = PressConfirmation()

    var selected: LauncherResult? {
        results.indices.contains(selectedIndex) ? results[selectedIndex] : nil
    }

    /// Actions available right now: the selected row's, then the mode's.
    var availableActions: [SecondaryAction] {
        (selected?.secondaryActions ?? []) + (handlers[mode]?.actions() ?? [])
    }

    var submitTitle: String? {
        if let handler = handlers[mode], handler.submit != nil { return handler.submitTitle }
        return selected?.actionTitle
    }

    func reset(to mode: Mode = .root) {
        self.mode = mode
        notice = nil
        confirmation.reset()
        results = []
        searchField?.stringValue = ""
        // The arguments form takes the keyboard; every other mode types into
        // the search field, so leaving the form hands it back.
        if mode != .scriptArguments, let field = searchField, field.currentEditor() == nil {
            field.window?.makeFirstResponder(field)
        }
        handlers[mode]?.entered?()
        if query.isEmpty {
            if let queryChanged = handlers[mode]?.queryChanged {
                queryChanged("")
            } else {
                refresh()
            }
        } else {
            query = ""
        }
    }

    /// The kept row's index in `rows`, once; nil when there is none.
    private func keptIndex(in rows: [LauncherResult]) -> Int? {
        defer { keepSelectionID = nil }
        guard let id = keepSelectionID else { return nil }
        return rows.firstIndex { $0.id == id }
    }

    /// Text typed into the search field while the arguments form was still
    /// taking the keyboard goes into the form's focused field, as if typed
    /// there. Waits up to 0.1 s for the field to take the keyboard; a form
    /// that cannot take it (a dropdown first) leaves the text where it is.
    func moveTypedAhead() async {
        for _ in 0..<10 {
            if let editor = searchField?.window?.firstResponder as? NSTextView, editor.isFieldEditor,
               (editor.delegate as? NSTextField) !== searchField {
                let typed = query
                guard !typed.isEmpty else { return }
                query = ""
                editor.insertText(typed, replacementRange: NSRange(location: NSNotFound, length: 0))
                return
            }
            guard (try? await Task.sleep(for: .milliseconds(10))) != nil else { return }
        }
    }

    func refresh() {
        if mode == .root {
            let started = ContinuousClock.now
            results = search(query)
            selectedIndex = keptIndex(in: results) ?? 0
            let elapsed = started.duration(to: .now)
            // Debug level is never persisted; visible only with `make logs`.
            Log.panel.debug("query “\(self.query, privacy: .public)” → \(self.results.count) results, top: \(self.results.first?.title ?? "-", privacy: .public) in \(elapsed, privacy: .public)")
            return
        }

        listTask?.cancel()
        guard let provider = handlers[mode]?.results else {
            results = []
            return
        }
        let query = query
        let mode = mode
        listTask = Task {
            let found = await provider(query)
            guard !Task.isCancelled, self.mode == mode, self.query == query else { return }
            results = found
            selectedIndex = keptIndex(in: found) ?? min(selectedIndex, max(found.count - 1, 0))
        }
    }

    func moveSelection(by delta: Int) {
        guard !results.isEmpty else { return }
        selectedIndex = min(max(selectedIndex + delta, 0), results.count - 1)
        confirmation.reset()
        notice = nil
    }

    func select(index: Int) {
        guard results.indices.contains(index) else { return }
        selectedIndex = index
    }

    func performSelected() {
        if let submit = handlers[mode]?.submit {
            submit()
            return
        }
        guard let item = selected else { return }
        perform(item.action)
    }

    /// Runs the action bound to `shortcut`, if any. Destructive actions
    /// need a second press within three seconds.
    func handle(_ shortcut: KeyShortcut) -> Bool {
        guard let action = availableActions.first(where: { $0.shortcut == shortcut }) else { return false }
        if action.confirm {
            let id = (selected?.id ?? "mode") + action.shortcut.display
            guard confirmation.press(id, at: .now) else {
                notice = "Press \(action.shortcut.display) again to \(action.title.lowercased())"
                return true
            }
        }
        notice = nil
        perform(action.action)
        return true
    }

    /// Esc leaves a sub-mode first, then closes the panel.
    func escape() {
        if let escape = handlers[mode]?.escape, escape() { return }
        if mode == .root {
            close()
        } else {
            reset(to: .root)
        }
    }

    private func perform(_ action: LauncherResult.Action) {
        switch action {
        case .run(let work):
            close()
            work()
        case .stay(let work):
            // A "press ↩ again" confirmation must land on the same row, so
            // the refresh after it keeps that row selected.
            let before = mode
            keepSelectionID = selected?.id
            work()
            if mode != before { keepSelectionID = nil }
            if handlers[mode]?.queryChanged == nil { refresh() }
        case .enter(let mode):
            reset(to: mode)
        }
    }
}
