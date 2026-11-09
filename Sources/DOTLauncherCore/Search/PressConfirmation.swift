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

    public mutating func reset() {
        armedID = nil
        armedAt = nil
    }
}
