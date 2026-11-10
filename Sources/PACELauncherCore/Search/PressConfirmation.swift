import Foundation

/// "Press again to confirm" without a dialog: the first press of an id arms
/// it, a second press of the same id within `window` seconds confirms.
public struct PressConfirmation {
    /// How long a first press counts, in seconds.
    public let window: TimeInterval
    private var armedAt: Date?
    public private(set) var armedID: String?

    public init(window: TimeInterval = 3) {
        self.window = window
    }

    public mutating func press(_ id: String, at date: Date) -> Bool {
        if isArmed(id, at: date) {
            reset()
            return true
        }
        armedID = id
        armedAt = date
        return false
    }

    /// For a press whose "press again" notice can disappear (typing,
    /// moving, reopening): once the notice is gone, the earlier press no
    /// longer counts, so this one only arms again.
    public mutating func press(_ id: String, at date: Date, stillShown: Bool) -> Bool {
        if !stillShown { reset() }
        return press(id, at: date)
    }

    /// True while a press of `id` would confirm.
    public func isArmed(_ id: String, at date: Date) -> Bool {
        guard armedID == id, let armedAt else { return false }
        // A clock that stepped back ends the arm rather than stretching it.
        let elapsed = date.timeIntervalSince(armedAt)
        return elapsed >= 0 && elapsed < window
    }

    public mutating func reset() {
        armedID = nil
        armedAt = nil
    }
}
