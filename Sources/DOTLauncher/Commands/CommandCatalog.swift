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
