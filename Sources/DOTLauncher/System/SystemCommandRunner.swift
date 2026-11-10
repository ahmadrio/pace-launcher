import AppKit
import DOTLauncherCore

/// Carries out a `SystemCommand`. `DOTSystemCommandDryRun` (a test hook,
/// like DOTDataRootOverride) only logs, so UI checks never lock, sleep or
/// log out the Mac.
enum SystemCommandRunner {
    static var isDryRun: Bool { UserDefaults.standard.bool(forKey: "DOTSystemCommandDryRun") }

    /// False when the command posts keys and Accessibility is not granted.
    @discardableResult
    static func run(_ command: SystemCommand) -> Bool {
        if command.needsAccessibility, !KeyboardPaste.canPost {
            AccessibilityPermission.prompt()
            return false
        }
        if isDryRun {
            Log.app.info("system command \(command.rawValue, privacy: .public) (dry run)")
            return true
        }
        Log.app.info("system command \(command.rawValue, privacy: .public)")
        switch command.action {
        case .keys(let combo):
            Task {
                // Let the panel order out, so the keys reach macOS, not DOT.
                try? await Task.sleep(for: .milliseconds(80))
                post(combo)
            }
        case .process(let path, let arguments):
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = arguments
            do {
                try process.run()
            } catch {
                Log.app.error("\(command.rawValue, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            }
        case .openApp(let path):
            let log = Log.app
            NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: path), configuration: NSWorkspace.OpenConfiguration()) { _, error in
                if let error { log.error("opening \(path, privacy: .public) failed: \(error.localizedDescription, privacy: .public)") }
            }
        }
        return true
    }

    private static func post(_ combo: KeyCombo) {
        var flags: CGEventFlags = []
        if combo.carbonModifiers & KeyCombo.command != 0 { flags.insert(.maskCommand) }
        if combo.carbonModifiers & KeyCombo.control != 0 { flags.insert(.maskControl) }
        if combo.carbonModifiers & KeyCombo.option != 0 { flags.insert(.maskAlternate) }
        if combo.carbonModifiers & KeyCombo.shift != 0 { flags.insert(.maskShift) }
        let source = CGEventSource(stateID: .combinedSessionState)
        let code = CGKeyCode(combo.keyCode)
        let down = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: false)
        down?.flags = flags
        up?.flags = flags
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
