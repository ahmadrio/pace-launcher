/// Every global shortcut DOT can register, as stored in settings.json.
public enum ShortcutID: Hashable, Sendable {
    case launcher
    case clipboardHistory
    case window(WindowAction)

    /// In the order Settings lists them.
    public static var allCases: [ShortcutID] {
        [.launcher, .clipboardHistory] + WindowAction.allCases.map { .window($0) }
    }

    /// "launcher", "clipboardHistory", "window.leftHalf".
    public var rawValue: String {
        switch self {
        case .launcher: "launcher"
        case .clipboardHistory: "clipboardHistory"
        case .window(let action): "window." + action.rawValue
        }
    }

    public init?(rawValue: String) {
        switch rawValue {
        case "launcher": self = .launcher
        case "clipboardHistory": self = .clipboardHistory
        default:
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
        }
    }

    /// ⌥Space for the launcher; Maccy's and Rectangle's habits for the rest.
    public var defaultCombo: KeyCombo? {
        switch self {
        case .launcher: KeyCombo("opt+space")
        case .clipboardHistory: KeyCombo("shift+opt+c")
        case .window(let action): action.defaultHotKey.flatMap(KeyCombo.init)
        }
    }

    /// The launcher must always have a shortcut, so DOT can be opened.
    public var isRequired: Bool { self == .launcher }
}
