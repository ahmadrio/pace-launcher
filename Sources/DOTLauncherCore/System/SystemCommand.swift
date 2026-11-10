/// System commands: what each does, as data, so the app only has to carry
/// it out. The AppleScript ones need Automation (Pace allowed it, tahap 17);
/// none needs Full Disk Access.
public enum SystemCommand: String, CaseIterable, Sendable {
    case lockScreen = "lock-screen"
    case sleep
    case sleepDisplays = "sleep-displays"
    case screenSaver = "screen-saver"
    case logOut = "log-out"
    case restart
    case shutDown = "shut-down"
    case emptyTrash = "empty-trash"
    case toggleDarkMode = "toggle-dark-mode"

    public enum Action: Equatable, Sendable {
        /// Posted as a key event (needs Accessibility).
        case keys(KeyCombo)
        case process(path: String, arguments: [String])
        case openApp(path: String)
        /// Run by osascript; `target` is the app it controls (Automation).
        case appleScript(source: String, target: String)
    }

    public var title: String {
        switch self {
        case .lockScreen: "Lock Screen"
        case .sleep: "Sleep"
        case .sleepDisplays: "Sleep Displays"
        case .screenSaver: "Start Screen Saver"
        case .logOut: "Log Out"
        case .restart: "Restart"
        case .shutDown: "Shut Down"
        case .emptyTrash: "Empty Trash"
        case .toggleDarkMode: "Toggle Dark Mode"
        }
    }

    public var subtitle: String {
        switch self {
        case .lockScreen: "Lock the Mac now"
        case .sleep: "Put the Mac to sleep"
        case .sleepDisplays: "Turn the displays off"
        case .screenSaver: "Start the screen saver"
        case .logOut: "Log out after macOS asks"
        case .restart: "Restart after macOS asks"
        case .shutDown: "Shut down after macOS asks"
        case .emptyTrash: "Delete the items in the Trash"
        case .toggleDarkMode: "Switch between light and dark appearance"
        }
    }

    public var aliases: [String] {
        switch self {
        case .lockScreen: ["lock", "kunci", "kunci layar"]
        case .sleep: ["tidur", "sleep mac"]
        case .sleepDisplays: ["display off", "matikan layar", "screen off"]
        case .screenSaver: ["screensaver"]
        case .logOut: ["logout", "sign out", "keluar"]
        case .restart: ["reboot", "mulai ulang", "restart mac"]
        case .shutDown: ["shutdown", "power off", "matikan", "matikan mac"]
        case .emptyTrash: ["trash", "bin", "kosongkan sampah", "tempat sampah"]
        case .toggleDarkMode: ["dark mode", "light mode", "mode gelap"]
        }
    }

    public var symbol: String {
        switch self {
        case .lockScreen: "lock"
        case .sleep: "moon"
        case .sleepDisplays: "display"
        case .screenSaver: "sparkles.tv"
        case .logOut: "rectangle.portrait.and.arrow.right"
        case .restart: "arrow.clockwise"
        case .shutDown: "power"
        case .emptyTrash: "trash"
        case .toggleDarkMode: "circle.lefthalf.filled"
        }
    }

    /// macOS's own shortcuts for lock (⌃⌘Q) and log out (⇧⌘Q, which shows
    /// its dialog); pmset for sleep; the screen saver app; Apple Events that
    /// ask loginwindow for its restart and shutdown dialogs, Finder to empty
    /// the Trash, and System Events to switch the appearance.
    public var action: Action {
        switch self {
        case .lockScreen: .keys(KeyCombo("ctrl+cmd+q")!)
        case .logOut: .keys(KeyCombo("shift+cmd+q")!)
        case .sleep: .process(path: "/usr/bin/pmset", arguments: ["sleepnow"])
        case .sleepDisplays: .process(path: "/usr/bin/pmset", arguments: ["displaysleepnow"])
        case .screenSaver: .openApp(path: "/System/Library/CoreServices/ScreenSaverEngine.app")
        case .restart: .appleScript(source: #"tell application "loginwindow" to «event aevtrrst»"#, target: "loginwindow")
        case .shutDown: .appleScript(source: #"tell application "loginwindow" to «event aevtrsdn»"#, target: "loginwindow")
        // A large Trash can take Finder longer than osascript's 2 minutes.
        case .emptyTrash: .appleScript(source: """
            with timeout of 3600 seconds
                tell application "Finder" to empty trash
            end timeout
            """, target: "Finder")
        case .toggleDarkMode: .appleScript(
            source: #"tell application "System Events" to tell appearance preferences to set dark mode to not dark mode"#,
            target: "System Events"
        )
        }
    }

    /// One stray ⏎ must not log out, restart, shut down or empty the Trash:
    /// these ask for a second ↩ with this notice.
    public var confirmationNotice: String? {
        switch self {
        case .logOut: "Press ↩ again to log out"
        case .restart: "Press ↩ again to restart"
        case .shutDown: "Press ↩ again to shut down"
        case .emptyTrash: "Press ↩ again to empty the Trash"
        default: nil
        }
    }

    public var needsConfirmation: Bool { confirmationNotice != nil }

    public var needsAccessibility: Bool {
        if case .keys = action { true } else { false }
    }
}
