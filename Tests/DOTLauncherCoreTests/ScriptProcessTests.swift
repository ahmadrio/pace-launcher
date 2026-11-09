import Foundation
import Testing
@testable import DOTLauncherCore

/// Collects what a ScriptProcess reports, across threads.
private final class Recorder: @unchecked Sendable {
    private let lock = NSLock()
    private var text = ""
    private var status: Int32?

    func add(_ data: Data) { lock.withLock { text += String(decoding: data, as: UTF8.self) } }
    func exit(_ code: Int32) { lock.withLock { status = code } }
    var output: String { lock.withLock { text } }
    var exitCode: Int32? { lock.withLock { status } }

    /// Polls until `condition` holds or `seconds` pass.
    func wait(_ seconds: Double, until condition: @Sendable (Recorder) -> Bool) async -> Bool {
        let deadline = Date.now.addingTimeInterval(seconds)
        while Date.now < deadline {
            if condition(self) { return true }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return condition(self)
    }
}

struct ScriptProcessTests {
    private func script(_ body: String, in folder: TemporaryFolder) throws -> URL {
        try folder.write("script.sh", "#!/bin/bash\n" + body)
        let url = folder.url.appending(path: "script.sh")
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return url
    }

    private func isAlive(_ pid: pid_t) -> Bool { kill(pid, 0) == 0 }

    @Test func `reports the exit while a background child keeps the output open`() async throws {
        let folder = TemporaryFolder()
        defer { folder.remove() }
        let url = try script("sleep 30 &\necho started\n", in: folder)
        let recorder = Recorder()
        let process = ScriptProcess(executable: url, arguments: [], directory: folder.url, environment: nil)
        try process.start(onOutput: { recorder.add($0) }, onExit: { recorder.exit($0) })
        defer { kill(-process.pid, SIGKILL) }

        #expect(await recorder.wait(5) { $0.exitCode != nil })
        #expect(recorder.exitCode == 0)
        #expect(recorder.output.contains("started"))
    }

    @Test func `stop ends the script and what it started in the background`() async throws {
        let folder = TemporaryFolder()
        defer { folder.remove() }
        let url = try script("sleep 300 &\necho $!\nwait\n", in: folder)
        let recorder = Recorder()
        let process = ScriptProcess(executable: url, arguments: [], directory: folder.url, environment: nil)
        try process.start(onOutput: { recorder.add($0) }, onExit: { recorder.exit($0) })
        defer { kill(-process.pid, SIGKILL) }

        #expect(await recorder.wait(5) { Int32($0.output.trimmingCharacters(in: .whitespacesAndNewlines)) != nil })
        let child = try #require(Int32(recorder.output.trimmingCharacters(in: .whitespacesAndNewlines)))
        #expect(isAlive(child))

        process.stop()

        #expect(await recorder.wait(5) { $0.exitCode != nil })
        #expect(await recorder.wait(3) { _ in kill(child, 0) != 0 })
    }

    @Test func `passes arguments as argv, never through a shell`() async throws {
        let folder = TemporaryFolder()
        defer { folder.remove() }
        let url = try script("printf '%s|' \"$@\"\n", in: folder)
        let recorder = Recorder()
        let process = ScriptProcess(executable: url, arguments: ["a b", "$HOME", "\"q\""], directory: folder.url, environment: nil)
        try process.start(onOutput: { recorder.add($0) }, onExit: { recorder.exit($0) })

        #expect(await recorder.wait(5) { $0.exitCode != nil })
        #expect(recorder.output == "a b|$HOME|\"q\"|")
    }
}
