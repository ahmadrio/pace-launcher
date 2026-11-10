import AppKit
import DOTLauncherCore

/// A built-in launcher command, ranked alongside apps.
struct LauncherCommand {
    let id: String
    let title: String
    let subtitle: String
    let aliases: [String]
    let symbol: String
    let actionTitle: String
    let action: LauncherResult.Action
    /// False when the action records its own use, e.g. only once it
    /// really runs (Log Out's first ↩ only asks to press again).
    var recordsUse = true

    var usageID: String { "cmd:" + id }
}

enum CommandCatalog {
    /// App-level commands, so everything in the menu bar menu is still
    /// reachable when the menu bar icon is hidden.
    static func appCommands(
        toggleIcon: @escaping () -> Void, iconVisible: @escaping () -> Bool, openSettings: @escaping () -> Void
    ) -> [LauncherCommand] {
        [
            LauncherCommand(
                id: "settings",
                title: "Settings",
                subtitle: "Appearance, snippets, scripts, sync",
                aliases: ["preferences", "settings"],
                symbol: "gearshape",
                actionTitle: "Open",
                action: .run(openSettings)
            ),
            LauncherCommand(
                id: "toggle-menu-bar-icon",
                title: "Toggle Menu Bar Icon",
                subtitle: iconVisible() ? "The icon is shown; run to hide it" : "The icon is hidden; run to show it",
                aliases: ["show menu bar icon", "hide menu bar icon"],
                symbol: "menubar.rectangle",
                actionTitle: "Toggle",
                action: .run(toggleIcon)
            ),
            LauncherCommand(
                id: "accessibility-settings",
                title: "Accessibility Settings",
                subtitle: AccessibilityPermission.isGranted ? "Accessibility: granted" : "Accessibility: not granted",
                aliases: ["permissions"],
                symbol: "hand.raised",
                actionTitle: "Open",
                action: .run {
                    if !AccessibilityPermission.isGranted { AccessibilityPermission.prompt() }
                    AccessibilityPermission.openSettings()
                }
            ),
            LauncherCommand(
                id: "quit",
                title: "Quit DOT Launcher",
                subtitle: "",
                aliases: ["exit"],
                symbol: "power",
                actionTitle: "Quit",
                action: .run { NSApp.terminate(nil) }
            ),
        ]
    }

    static func windowCommands(perform: @escaping (WindowAction) -> Void) -> [LauncherCommand] {
        WindowAction.allCases.map { action in
            let shortcut = action.defaultHotKey.flatMap(KeyCombo.init)?.displayString
            return LauncherCommand(
                id: "window-\(action.rawValue)",
                title: action.title,
                subtitle: ["Window Management", shortcut].compactMap { $0 }.joined(separator: " · "),
                aliases: ["window " + action.title.lowercased()],
                symbol: symbol(for: action),
                actionTitle: "Run",
                action: .run { perform(action) }
            )
        }
    }

    private static func symbol(for action: WindowAction) -> String {
        switch action {
        case .leftHalf: "rectangle.lefthalf.filled"
        case .rightHalf: "rectangle.righthalf.filled"
        case .topHalf: "rectangle.tophalf.filled"
        case .bottomHalf: "rectangle.bottomhalf.filled"
        case .topLeft: "rectangle.inset.topleft.filled"
        case .topRight: "rectangle.inset.topright.filled"
        case .bottomLeft: "rectangle.inset.bottomleft.filled"
        case .bottomRight: "rectangle.inset.bottomright.filled"
        case .maximize: "rectangle.fill"
        case .almostMaximize: "rectangle.inset.filled"
        case .center: "rectangle.center.inset.filled"
        case .restore: "arrow.uturn.backward"
        }
    }

    static func snippetCommands(create: @escaping () -> Void) -> [LauncherCommand] {
        [
            LauncherCommand(
                id: "search-snippets",
                title: "Search Snippets",
                subtitle: "Paste saved text",
                aliases: ["snippet", "snip"],
                symbol: "text.quote",
                actionTitle: "Open",
                action: .enter(.snippets)
            ),
            LauncherCommand(
                id: "create-snippet",
                title: "Create Snippet",
                subtitle: "Save text you type often",
                aliases: ["new snippet"],
                symbol: "plus.square.on.square",
                actionTitle: "Create",
                action: .run(create)
            ),
        ]
    }

    static func quicklinkCommands(create: @escaping () -> Void) -> [LauncherCommand] {
        [
            LauncherCommand(
                id: "create-quicklink",
                title: "Create Quicklink",
                subtitle: "Save a URL to open from here",
                aliases: ["new quicklink", "link"],
                symbol: "link.badge.plus",
                actionTitle: "Create",
                action: .run(create)
            ),
        ]
    }

    static func noteCommands(open: @escaping () -> Void, create: @escaping () -> Void) -> [LauncherCommand] {
        [
            LauncherCommand(
                id: "open-notes", title: "Open Notes", subtitle: "Floating Markdown notes",
                aliases: [], symbol: "note.text", actionTitle: "Open", action: .run(open)
            ),
            LauncherCommand(
                id: "create-note", title: "Create Note", subtitle: "Start a new note",
                aliases: ["new note"], symbol: "square.and.pencil", actionTitle: "Create", action: .run(create)
            ),
            LauncherCommand(
                id: "search-notes", title: "Search Notes", subtitle: "Find and open a note",
                aliases: ["notes", "note"], symbol: "magnifyingglass", actionTitle: "Open", action: .enter(.notes)
            ),
        ]
    }

    static func scriptCommands(create: @escaping () -> Void, openFolder: @escaping () -> Void) -> [LauncherCommand] {
        [
            LauncherCommand(
                id: "create-script", title: "Create Script Command", subtitle: "Start a new shell script in the Scripts folder",
                aliases: ["new script"], symbol: "terminal", actionTitle: "Create", action: .run(create)
            ),
            LauncherCommand(
                id: "open-scripts-folder", title: "Open Scripts Folder", subtitle: "Where DOT looks for script commands",
                aliases: ["scripts"], symbol: "folder", actionTitle: "Open", action: .run(openFolder)
            ),
        ]
    }

    static func aiChat() -> LauncherCommand {
        LauncherCommand(
            id: "ai-chat",
            title: "AI Chat",
            subtitle: "Ask Apple's on-device model",
            aliases: ["ai", "ask", "chat"],
            symbol: "sparkles",
            actionTitle: "Open",
            action: .enter(.ai)
        )
    }

    static func searchEmoji() -> LauncherCommand {
        LauncherCommand(
            id: "search-emoji",
            title: "Search Emoji",
            subtitle: "Paste an emoji into any app",
            aliases: ["emoji", "emoticon", "emoji picker"],
            symbol: "face.smiling",
            actionTitle: "Open",
            action: .enter(.emoji)
        )
    }

    static func aiChatHistory() -> LauncherCommand {
        LauncherCommand(
            id: "ai-chat-history",
            title: "AI Chat History",
            subtitle: "Reopen and continue saved AI chats",
            aliases: ["ai history", "chats", "chat history"],
            symbol: "clock.arrow.circlepath",
            actionTitle: "Open",
            action: .enter(.chatHistory)
        )
    }

    static func translate() -> LauncherCommand {
        LauncherCommand(
            id: "translate",
            title: "Translate",
            subtitle: "Indonesian ↔ English, on-device",
            aliases: ["translate", "terjemah", "tr"],
            symbol: "character.book.closed",
            actionTitle: "Open",
            action: .enter(.translate)
        )
    }

    static func clipboardHistory() -> LauncherCommand {
        LauncherCommand(
            id: "clipboard-history",
            title: "Clipboard History",
            subtitle: "Search and paste anything you copied",
            aliases: ["clip", "clipboard", "paste history"],
            symbol: "doc.on.clipboard",
            actionTitle: "Open",
            action: .enter(.clipboard)
        )
    }
}
