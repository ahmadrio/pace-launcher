/// One run at a time per key. A busy key either queues the next job (runs
/// that must not overlap, like Toggle Dark Mode's read-then-set) or drops
/// it (a second Restart while macOS's dialog is still up).
public struct ScriptRunQueue<Key: Hashable, Job> {
    public enum Decision {
        /// Start this job now; the key is now running.
        case start(Job)
        /// Waits until the running job finishes.
        case queued
        /// Not started: the key is busy and does not queue.
        case dropped
    }

    private var running: Set<Key> = []
    private var waiting: [Key: [Job]] = [:]

    public init() {}

    public mutating func submit(_ job: Job, for key: Key, queueIfBusy: Bool) -> Decision {
        guard running.contains(key) else {
            running.insert(key)
            return .start(job)
        }
        guard queueIfBusy else { return .dropped }
        waiting[key, default: []].append(job)
        return .queued
    }

    /// The key's run ended (or failed to start). Returns the next job to
    /// start, which keeps the key running, or nil when the key is idle.
    public mutating func finish(_ key: Key) -> Job? {
        if var jobs = waiting[key], !jobs.isEmpty {
            let next = jobs.removeFirst()
            waiting[key] = jobs.isEmpty ? nil : jobs
            return next
        }
        running.remove(key)
        return nil
    }

    public func isRunning(_ key: Key) -> Bool {
        running.contains(key)
    }
}
