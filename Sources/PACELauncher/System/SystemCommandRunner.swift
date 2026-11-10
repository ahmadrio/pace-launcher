import AppKit
import PACELauncherCore

/// Carries out a `SystemCommand`. `PACESystemCommandDryRun` (a test hook,
/// like PACEDataRootOverride) only logs, so UI checks never lock, sleep, log
/// out, restart, shut down, empty the Trash or switch the appearance.
enum SystemCommandRunner {
    static var isDryRun: Bool { UserDefaults.standard.bool(forKey: "PACESystemCommandDryRun") }

    /// False when the command posts keys and Accessibility is not granted.
    /// `onFocusStuck` runs when PACE could not give up keyboard focus;
    /// `onScriptEnd` when an AppleScript command's osascript has finished.
    @discardableResult
    static func run(
        _ command: SystemCommand,
        onFocusStuck: @escaping @MainActor () -> Void = {},
        onScriptEnd: @escaping @MainActor (AppleScriptEnd) -> Void = { _ in }
    ) -> Bool {
        // A dry run posts nothing, so it needs no permission (and no prompt).
        if command.needsAccessibility, !isDryRun, !KeyboardPaste.canPost {
            AccessibilityPermission.prompt()
            return false
        }
        if case .keys(let combo) = command.action {
            // ⌃⌘Q and ⇧⌘Q are the frontmost app's Apple-menu shortcuts: if a
            // PACE window (Settings, the panel) holds focus they reach PACE,
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
                    Log.app.notice("system command \(command.rawValue, privacy: .public) skipped: PACE kept the keyboard focus")
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
        case .appleScript(let source, _):
            runAppleScript(source, for: command, onEnd: onScriptEnd)
        }
        return true
    }

    /// osascript is a child of PACE, so macOS asks (and remembers) Automation
    /// for PACE Launcher; it runs off the main thread, which matters while
    /// the permission dialog or macOS's restart dialog is up.
    private typealias ScriptRun = (source: String, onEnd: @MainActor (AppleScriptEnd) -> Void)
    /// One run per command: Toggle Dark Mode queues a repeat (it reads, then
    /// sets the appearance); the others drop it while still running.
    private static var scriptRuns = ScriptRunQueue<SystemCommand, ScriptRun>()

    private static func runAppleScript(_ source: String, for command: SystemCommand, onEnd: @escaping @MainActor (AppleScriptEnd) -> Void) {
        switch scriptRuns.submit((source, onEnd), for: command, queueIfBusy: command.queuesRepeatRuns) {
        case .start(let run):
            launch(run, for: command)
        case .queued:
            Log.app.info("system command \(command.rawValue, privacy: .public) waits for its previous run")
        case .dropped:
            Log.app.notice("system command \(command.rawValue, privacy: .public) is already running")
            onEnd(.alreadyRunning)
        }
    }

    private static func launch(_ run: ScriptRun, for command: SystemCommand) {
        Log.app.info("system command \(command.rawValue, privacy: .public) started")
        start(run.source, for: command) { end in
            // Anything but done is kept (.notice) so it can be read later;
            // only the command id and osascript's ending are logged.
            if end == .done {
                Log.app.info("system command \(command.rawValue, privacy: .public) finished: done")
            } else {
                Log.app.notice("system command \(command.rawValue, privacy: .public) finished: \(String(describing: end), privacy: .public)")
            }
            run.onEnd(end)
            if let next = scriptRuns.finish(command) { launch(next, for: command) }
        }
    }

    private static func start(_ source: String, for command: SystemCommand, onEnd: @escaping @MainActor (AppleScriptEnd) -> Void) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", source]
        let errors = Pipe()
        process.standardError = errors
        process.standardOutput = FileHandle.nullDevice
        let log = Log.app
        let name = command.rawValue
        process.terminationHandler = { process in
            let output = String(decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            let end = AppleScriptEnd(status: process.terminationStatus, errorOutput: output)
            Task { @MainActor in onEnd(end) }
        }
        do {
            try process.run()
        } catch {
            log.error("\(name, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            onEnd(.failed(error.localizedDescription))
        }
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
