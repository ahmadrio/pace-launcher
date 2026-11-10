import AppKit
import DOTLauncherCore

/// Carries out a `SystemCommand`. `DOTSystemCommandDryRun` (a test hook,
/// like DOTDataRootOverride) only logs, so UI checks never lock, sleep or
/// log out the Mac.
enum SystemCommandRunner {
    static var isDryRun: Bool { UserDefaults.standard.bool(forKey: "DOTSystemCommandDryRun") }

    /// False when the command posts keys and Accessibility is not granted.
    /// `onFocusStuck` runs when DOT could not give up keyboard focus.
    @discardableResult
    static func run(_ command: SystemCommand, onFocusStuck: @escaping @MainActor () -> Void = {}) -> Bool {
        if command.needsAccessibility, !KeyboardPaste.canPost {
            AccessibilityPermission.prompt()
            return false
        }
        if case .keys(let combo) = command.action {
            // ⌃⌘Q and ⇧⌘Q are the frontmost app's Apple-menu shortcuts: if a
            // DOT window (Settings, the panel) holds focus they reach DOT,
            // which has no Apple menu, and nothing happens. Step aside first.
            if NSApp.isActive || NSApp.keyWindow != nil { NSApp.hide(nil) }
            Task {
                for _ in 0..<20 where NSApp.isActive || NSApp.keyWindow != nil {
                    try? await Task.sleep(for: .milliseconds(50))
                }
                try? await Task.sleep(for: .milliseconds(80))
                let released = !NSApp.isActive && NSApp.keyWindow == nil
                if isDryRun {
                    Log.app.info("system command \(command.rawValue, privacy: .public) (dry run, focus released: \(released))")
                    return
                }
                guard released else {
                    Log.app.notice("system command \(command.rawValue, privacy: .public) skipped: DOT kept the keyboard focus")
                    onFocusStuck()
                    return
                }
                Log.app.info("system command \(command.rawValue, privacy: .public)")
                post(combo)
            }
            return true
        }
        if isDryRun {
            Log.app.info("system command \(command.rawValue, privacy: .public) (dry run)")
            return true
        }
        Log.app.info("system command \(command.rawValue, privacy: .public)")
        switch command.action {
        case .keys:
            break
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
