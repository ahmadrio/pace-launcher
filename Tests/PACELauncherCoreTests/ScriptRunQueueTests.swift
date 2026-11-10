import Testing
@testable import PACELauncherCore

struct ScriptRunQueueTests {
    @Test func `queued runs start in order after each finish`() {
        var queue = ScriptRunQueue<String, String>()
        guard case .start("a1") = queue.submit("a1", for: "dark", queueIfBusy: true) else {
            Issue.record("an idle command starts at once")
            return
        }
        guard case .queued = queue.submit("a2", for: "dark", queueIfBusy: true),
              case .queued = queue.submit("a3", for: "dark", queueIfBusy: true)
        else {
            Issue.record("a busy queueing command waits")
            return
        }
        #expect(queue.isRunning("dark"))
        #expect(queue.finish("dark") == "a2")
        #expect(queue.isRunning("dark"))
        #expect(queue.finish("dark") == "a3")
        #expect(queue.finish("dark") == nil)
        #expect(!queue.isRunning("dark"))
    }

    @Test func `a busy command drops repeats unless it queues them`() {
        var queue = ScriptRunQueue<String, String>()
        guard case .start = queue.submit("r1", for: "restart", queueIfBusy: false) else {
            Issue.record("an idle command starts at once")
            return
        }
        guard case .dropped = queue.submit("r2", for: "restart", queueIfBusy: false) else {
            Issue.record("a repeat of a busy command is dropped")
            return
        }
        guard case .start = queue.submit("t1", for: "trash", queueIfBusy: false) else {
            Issue.record("another command is not held up")
            return
        }
        // A run that fails to start is finished at once, which frees its command.
        #expect(queue.finish("restart") == nil)
        #expect(!queue.isRunning("restart"))
        guard case .start("r3") = queue.submit("r3", for: "restart", queueIfBusy: false) else {
            Issue.record("a finished command starts again")
            return
        }
    }
}
