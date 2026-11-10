/// Tells the latest run of a repeated job from older ones, so a stale
/// task finishing late never undoes a newer task's state.
public struct RunToken: Sendable {
    private var current = 0

    public init() {}

    /// Starts a new run and returns its number.
    public mutating func begin() -> Int {
        current += 1
        return current
    }

    public func isCurrent(_ run: Int) -> Bool { run == current }
}
