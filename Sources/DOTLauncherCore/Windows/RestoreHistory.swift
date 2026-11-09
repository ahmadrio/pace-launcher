import CoreGraphics

/// The frame each window had before it was first snapped, so "Restore"
/// can put it back. Snapping again keeps the original.
public struct RestoreHistory<Key: Hashable> {
    private var frames: [Key: CGRect] = [:]
    private var order: [Key] = []
    private let capacity: Int

    public init(capacity: Int = 50) {
        self.capacity = capacity
    }

    public mutating func remember(_ frame: CGRect, for key: Key) {
        guard frames[key] == nil else { return }
        frames[key] = frame
        order.append(key)
        if order.count > capacity {
            frames[order.removeFirst()] = nil
        }
    }

    public mutating func take(for key: Key) -> CGRect? {
        guard let frame = frames.removeValue(forKey: key) else { return nil }
        order.removeAll { $0 == key }
        return frame
    }
}
