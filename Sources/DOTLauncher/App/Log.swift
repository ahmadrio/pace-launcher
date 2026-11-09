import os

/// Loggers for `make logs` (`log stream --predicate 'subsystem == "com.pace.DOTLauncher"'`).
enum Log {
    private static let subsystem = "com.pace.DOTLauncher"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let hotkeys = Logger(subsystem: subsystem, category: "hotkeys")
    static let panel = Logger(subsystem: subsystem, category: "panel")
    static let apps = Logger(subsystem: subsystem, category: "apps")
    static let clipboard = Logger(subsystem: subsystem, category: "clipboard")
    static let windows = Logger(subsystem: subsystem, category: "windows")
}
