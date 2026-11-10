/// System commands DOT can run without new permissions: what each does,
/// as data, so the app only has to carry it out.
public enum SystemCommand: String, CaseIterable, Sendable {
    case lockScreen = "lock-screen"
    case sleep
    case sleepDisplays = "sleep-displays"
    case screenSaver = "screen-saver"
    case logOut = "log-out"

    public enum Action: Equatable, Sendable {
        /// Posted as a key event (needs Accessibility).
        case keys(KeyCombo)
        case process(path: String, arguments: [String])
        case openApp(path: String)
    }

    public var title: String {
        switch self {
        case .lockScreen: "Lock Screen"
        case .sleep: "Sleep"
        case .sleepDisplays: "Sleep Displays"
        case .screenSaver: "Start Screen Saver"
        case .logOut: "Log Out"
        }
    }

    public var subtitle: String {
        switch self {
        case .lockScreen: "Lock the Mac now"
        case .sleep: "Put the Mac to sleep"
        case .sleepDisplays: "Turn the displays off"
        case .screenSaver: "Start the screen saver"
        case .logOut: "Log out after macOS asks"
        }
    }

    public var aliases: [String] {
        switch self {
        case .lockScreen: ["lock", "kunci", "kunci layar"]
        case .sleep: ["tidur", "sleep mac"]
        case .sleepDisplays: ["display off", "matikan layar", "screen off"]
        case .screenSaver: ["screensaver"]
        case .logOut: ["logout", "sign out", "keluar"]
        }
    }

    public var symbol: String {
        switch self {
        case .lockScreen: "lock"
        case .sleep: "moon"
        case .sleepDisplays: "display"
        case .screenSaver: "sparkles.tv"
        case .logOut: "rectangle.portrait.and.arrow.right"
        }
    }

    /// macOS's own shortcuts for lock (⌃⌘Q) and log out (⇧⌘Q, which shows
    /// its dialog); pmset for sleep; the screen saver app.
    public var action: Action {
        switch self {
        case .lockScreen: .keys(KeyCombo("ctrl+cmd+q")!)
        case .logOut: .keys(KeyCombo("shift+cmd+q")!)
        case .sleep: .process(path: "/usr/bin/pmset", arguments: ["sleepnow"])
        case .sleepDisplays: .process(path: "/usr/bin/pmset", arguments: ["displaysleepnow"])
        case .screenSaver: .openApp(path: "/System/Library/CoreServices/ScreenSaverEngine.app")
        }
    }

    /// One stray ⏎ must not log the user out.
    public var needsConfirmation: Bool { self == .logOut }

    public var needsAccessibility: Bool {
        if case .keys = action { true } else { false }
    }
}
