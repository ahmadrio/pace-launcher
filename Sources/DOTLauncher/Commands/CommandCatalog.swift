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

    var usageID: String { "cmd:" + id }
}

enum CommandCatalog {
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
