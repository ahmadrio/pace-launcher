import AppKit
import DOTLauncherCore

/// Expands snippet keywords as they are typed in any app: deletes the
/// keyword with backspaces, then pastes the snippet (clipboard restored).
final class AutoExpandController {
    private let monitor = KeystrokeMonitor()
    private let library: SnippetLibrary
    private let settings: SettingsStore
    private let pasteMonitor: () -> PasteboardMonitor?
    private var expander = KeywordExpander(keywords: [])
    private var snippetsByKeyword: [String: Snippet] = [:]
    private var lastKeystroke = Date.distantPast
    private var isExpanding = false
    private var appWatch: Task<Void, Never>?

    init(library: SnippetLibrary, settings: SettingsStore, pasteMonitor: @escaping () -> PasteboardMonitor?) {
        self.library = library
        self.settings = settings
        self.pasteMonitor = pasteMonitor
        monitor.onText = { [weak self] in self?.typed($0) }
        monitor.onDelete = { [weak self] in self?.expander.deleteBackward() }
        monitor.onReset = { [weak self] in self?.expander.reset() }
    }

    enum Status: Equatable { case off, needsPermission, on }

    var status: Status {
        guard settings.data.autoExpandEnabled else { return .off }
        return monitor.isRunning ? .on : .needsPermission
    }

    /// Applies the current settings: starts or stops the tap.
    func refresh() {
        reloadKeywords()
        if settings.data.autoExpandEnabled {
            if !monitor.start() { KeystrokeMonitor.requestPermission() }
            watchAppSwitches()
        } else {
            monitor.stop()
        }
    }

    func reloadKeywords() {
        var byKeyword: [String: Snippet] = [:]
        for snippet in library.snippets {
            if let keyword = snippet.keyword, !keyword.isEmpty { byKeyword[keyword] = snippet }
        }
        snippetsByKeyword = byKeyword
        expander = KeywordExpander(keywords: Array(byKeyword.keys))
    }

    private func typed(_ text: String) {
        guard !isExpanding, settings.data.autoExpandEnabled else { return }
        let now = Date.now
        if now.timeIntervalSince(lastKeystroke) > 5 { expander.reset() }
        lastKeystroke = now

        let front = NSWorkspace.shared.frontmostApplication
        guard AutoExpandRule.allows(
            frontmostBundleID: front?.bundleIdentifier,
            dotIsFrontmost: front?.processIdentifier == getpid(),
            dotHasKeyWindow: NSApp.keyWindow != nil,
            excluded: settings.data.autoExpandExcludedBundleIDs
        ) else {
            expander.reset()
            return
        }
        guard let keyword = expander.type(text), let snippet = snippetsByKeyword[keyword] else { return }
        expand(snippet, replacing: keyword)
    }

    private func expand(_ snippet: Snippet, replacing keyword: String) {
        isExpanding = true
        let clipboard = NSPasteboard.general.string(forType: .string)
        let text = SnippetExpander.expand(snippet.content, now: .now, clipboard: clipboard)
        Log.app.info("auto-expanding a snippet keyword")

        let source = CGEventSource(stateID: .combinedSessionState)
        for _ in 0..<keyword.count {
            let down = CGEvent(keyboardEventSource: source, virtualKey: 51, keyDown: true)
            let up = CGEvent(keyboardEventSource: source, virtualKey: 51, keyDown: false)
            down?.post(tap: .cghidEventTap)
            up?.post(tap: .cghidEventTap)
        }
        // ⌘V goes out right behind the backspaces: the app handles events in
        // order, and anything typed next queues up after the paste.
        TextPaster.paste(text, monitor: pasteMonitor(), delay: .zero)
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            expander.reset()
            isExpanding = false
        }
    }

    private func watchAppSwitches() {
        guard appWatch == nil else { return }
        appWatch = Task { [weak self] in
            for await _ in NSWorkspace.shared.notificationCenter.notifications(named: NSWorkspace.didActivateApplicationNotification) {
                self?.expander.reset()
            }
        }
    }
}
