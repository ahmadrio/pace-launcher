import Foundation

/// "Press again to confirm" without a dialog: the first press of an id arms
/// it, a second press of the same id within `window` seconds confirms.
public struct PressConfirmation {
    private let window: TimeInterval
    private var armedAt: Date?
    public private(set) var armedID: String?

    public init(window: TimeInterval = 3) {
        self.window = window
    }

    public mutating func press(_ id: String, at date: Date) -> Bool {
        if armedID == id, let armedAt, date.timeIntervalSince(armedAt) < window {
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
        return date.timeIntervalSince(armedAt) < window
    }

    public mutating func reset() {
        armedID = nil
        armedAt = nil
    }
}
