/// Every global shortcut DOT can register, as stored in settings.json.
public enum ShortcutID: Hashable, Sendable {
    case launcher
    case clipboardHistory
    case command(CommandShortcut)
    case window(WindowAction)
    /// A script command, by `ScriptShortcut.key`.
    case script(String)

    /// How Settings › Shortcuts groups the rows.
    public enum Group: Sendable, Hashable { case launcher, commands, scripts, window }

    public var group: Group {
        switch self {
        case .launcher, .clipboardHistory: .launcher
        case .command: .commands
        case .window: .window
        case .script: .scripts
        }
    }

    /// In the order Settings lists them.
    public static var allCases: [ShortcutID] {
        [.launcher, .clipboardHistory] + CommandShortcut.allCases.map { .command($0) } + WindowAction.allCases.map { .window($0) }
    }

    /// "launcher", "clipboardHistory", "window.leftHalf", "script.tools/deploy.sh".
    public var rawValue: String {
        switch self {
        case .launcher: "launcher"
        case .clipboardHistory: "clipboardHistory"
        case .window(let action): "window." + action.rawValue
        case .command(let command): "command." + command.rawValue
        case .script(let key): "script." + key
        }
    }

    public init?(rawValue: String) {
        switch rawValue {
        case "launcher": self = .launcher
        case "clipboardHistory": self = .clipboardHistory
        default:
            if rawValue.hasPrefix("script.") {
                let key = String(rawValue.dropFirst("script.".count))
                guard !key.isEmpty else { return nil }
                self = .script(key)
                return
            }
            if rawValue.hasPrefix("command.") {
                guard let command = CommandShortcut(rawValue: String(rawValue.dropFirst("command.".count))) else { return nil }
                self = .command(command)
                return
            }
            guard rawValue.hasPrefix("window."),
                  let action = WindowAction(rawValue: String(rawValue.dropFirst("window.".count)))
            else { return nil }
            self = .window(action)
        }
    }

    public var title: String {
        switch self {
        case .launcher: "Open DOT Launcher"
        case .clipboardHistory: "Clipboard History"
        case .window(let action): action.title
        case .command(let command): command.title
        // The file name; Settings and menus show the script's own title.
        case .script(let key): key.split(separator: "/").last.map(String.init) ?? key
        }
    }

    /// ⌥Space for the launcher; Maccy's and Rectangle's habits for the rest.
    public var defaultCombo: KeyCombo? {
        switch self {
        case .launcher: KeyCombo("opt+space")
        case .clipboardHistory: KeyCombo("shift+opt+c")
        case .window(let action): action.defaultHotKey.flatMap(KeyCombo.init)
        case .command, .script: nil
        }
    }

    /// The launcher must always have a shortcut, so DOT can be opened.
    public var isRequired: Bool { self == .launcher }
}
