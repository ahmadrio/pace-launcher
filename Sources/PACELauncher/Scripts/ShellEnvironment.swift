import Foundation

/// The environment of the user's login shell. Apps started from Finder get
/// a minimal PATH, so tools installed with Homebrew, fnm, etc. would not be
/// found by scripts without this.
enum ShellEnvironment {
    private(set) static var current: [String: String] = fallback

    /// Loads the login-shell environment once (5 s timeout).
    static func load() async {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        guard let output = await capture(shell, ["-l", "-c", "env"], timeout: .seconds(5)) else {
            Log.app.notice("login shell environment unavailable; using a fallback PATH")
            return
        }
        var environment: [String: String] = [:]
        for line in output.split(separator: "\n") {
            guard let equals = line.firstIndex(of: "=") else { continue }
            environment[String(line[..<equals])] = String(line[line.index(after: equals)...])
        }
        if environment["PATH"] != nil {
            current = environment
        }
    }

    private static var fallback: [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + (environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin")
        return environment
    }

    /// Runs a short command off the main actor and returns its stdout.
    @concurrent
    private static func capture(_ executable: String, _ arguments: [String], timeout: Duration) async -> String? {
        let process = Process()
        process.executableURL = URL(filePath: executable)
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return nil
        }
        // Wait first (with a deadline), then read: reading to EOF up front
        // would block forever on a shell that hangs. `env` output is far
        // smaller than the pipe buffer, so the shell can't stall on writing.
        let deadline = ContinuousClock.now + timeout
        while process.isRunning, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(20))
        }
        if process.isRunning {
            process.terminate()
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return process.terminationStatus == 0 ? String(decoding: data, as: UTF8.self) : nil
    }
}
