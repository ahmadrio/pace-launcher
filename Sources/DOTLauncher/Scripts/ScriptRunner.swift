import DOTLauncherCore
import Foundation
import Observation

/// One run of a script: its streamed output and exit status.
@Observable
final class ScriptRun {
    /// Output beyond this is dropped so a chatty script can't bloat DOT.
    static let maxOutputBytes = 1_000_000

    let script: ScriptCommand
    private(set) var output = ""
    private(set) var isRunning = true
    private(set) var exitCode: Int32?
    /// Set when the script could not be started at all.
    private(set) var launchError: String?

    @ObservationIgnored var onFinish: ((ScriptRun) -> Void)?
    @ObservationIgnored fileprivate var process: Process?
    @ObservationIgnored private var receivedBytes = 0

    init(script: ScriptCommand) {
        self.script = script
    }

    var succeeded: Bool { exitCode == 0 && launchError == nil }

    /// The last non-empty output line (for the HUD).
    var lastLine: String {
        output.split(whereSeparator: \.isNewline).last { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map(String.init) ?? ""
    }

    /// Asks the script to stop (SIGTERM), then kills it after a second.
    func stop() {
        guard isRunning, let process else { return }
        process.terminate()
        let pid = process.processIdentifier
        Task {
            try? await Task.sleep(for: .seconds(1))
            if self.isRunning { kill(pid, SIGKILL) }
        }
    }

    fileprivate func append(_ data: Data) {
        guard receivedBytes < Self.maxOutputBytes else { return }
        receivedBytes += data.count
        output += ANSI.strip(String(decoding: data, as: UTF8.self))
        if receivedBytes >= Self.maxOutputBytes {
            output += "\n…output truncated"
        }
    }

    fileprivate func finish(status: Int32) {
        isRunning = false
        exitCode = status
        process = nil
        onFinish?(self)
    }

    fileprivate func fail(_ message: String) {
        isRunning = false
        launchError = message
        output = message
        onFinish?(self)
    }
}

/// Starts scripts as their own processes (argv, never through a shell).
enum ScriptRunner {
    /// Runs stay alive until they finish, even when no view holds them
    /// (compact and silent scripts have no output view).
    private static var active: [ObjectIdentifier: ScriptRun] = [:]

    static func run(_ script: ScriptCommand, arguments: [String] = []) -> ScriptRun {
        let run = ScriptRun(script: script)
        let key = ObjectIdentifier(run)
        active[key] = run
        let process = Process()
        process.executableURL = script.url
        process.arguments = arguments
        process.currentDirectoryURL = workingDirectory(for: script)
        process.environment = ShellEnvironment.current
        process.standardInput = FileHandle.nullDevice

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        let reader = pipe.fileHandleForReading

        reader.readabilityHandler = { [weak run] handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                handle.readabilityHandler = nil
                return
            }
            Task { @MainActor in run?.append(data) }
        }
        process.terminationHandler = { [weak run] finished in
            let status = finished.terminationStatus
            reader.readabilityHandler = nil
            let rest = reader.readDataToEndOfFile()
            Task { @MainActor in
                if !rest.isEmpty { run?.append(rest) }
                run?.finish(status: status)
                active[key] = nil
            }
        }

        do {
            try process.run()
            run.process = process
        } catch {
            reader.readabilityHandler = nil
            active[key] = nil
            run.fail(script.isExecutable
                ? "Could not start: \(error.localizedDescription)"
                : "Not executable. Use “Make Executable” (⌘⇧X) or run chmod +x.")
        }
        return run
    }

    private static func workingDirectory(for script: ScriptCommand) -> URL {
        if let path = script.metadata.currentDirectoryPath {
            let expanded = (path as NSString).expandingTildeInPath
            let url = expanded.hasPrefix("/")
                ? URL(filePath: expanded)
                : script.url.deletingLastPathComponent().appending(path: expanded)
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        return script.url.deletingLastPathComponent()
    }
}
