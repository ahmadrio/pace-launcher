import Foundation

/// Runs one executable with argv (never through a shell) and streams its
/// combined stdout and stderr.
///
/// `onExit` fires as soon as the script exits, even when something it
/// started in the background still holds the output pipe open.
public final class ScriptProcess: @unchecked Sendable {
    private let process = Process()

    public var pid: pid_t { process.processIdentifier }

    public init(executable: URL, arguments: [String], directory: URL, environment: [String: String]?) {
        process.executableURL = executable
        process.arguments = arguments
        process.currentDirectoryURL = directory
        if let environment { process.environment = environment }
        process.standardInput = FileHandle.nullDevice
    }

    /// Both callbacks run on background threads.
    public func start(onOutput: @escaping @Sendable (Data) -> Void, onExit: @escaping @Sendable (Int32) -> Void) throws {
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        let reader = pipe.fileHandleForReading

        reader.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                handle.readabilityHandler = nil
                return
            }
            onOutput(data)
        }
        process.terminationHandler = { finished in
            // Take what is already in the pipe, but never wait for EOF:
            // a background child may keep the pipe open for hours.
            reader.readabilityHandler = nil
            let rest = Self.readAvailable(from: reader.fileDescriptor)
            if !rest.isEmpty { onOutput(rest) }
            onExit(finished.terminationStatus)
        }
        do {
            try process.run()
        } catch {
            reader.readabilityHandler = nil
            throw error
        }
    }

    /// SIGTERM (Foundation sends it to the script's process group, so
    /// background children stop too), then SIGKILL to the group after 1 s.
    public func stop() {
        guard process.isRunning else { return }
        let pid = process.processIdentifier
        process.terminate()
        DispatchQueue.global().asyncAfter(deadline: .now() + 1) { [self] in
            guard process.isRunning else { return }
            // Never signal DOT's own group.
            if getpgid(pid) == pid, pid != getpgrp() {
                kill(-pid, SIGKILL)
            } else {
                kill(pid, SIGKILL)
            }
        }
    }

    /// Reads whatever is buffered in the pipe without blocking.
    private static func readAvailable(from descriptor: Int32) -> Data {
        _ = fcntl(descriptor, F_SETFL, fcntl(descriptor, F_GETFL) | O_NONBLOCK)
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 65_536)
        while true {
            let count = read(descriptor, &buffer, buffer.count)
            guard count > 0 else { break }
            data.append(contentsOf: buffer[0..<count])
        }
        return data
    }
}
