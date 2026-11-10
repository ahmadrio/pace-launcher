/// A small cache that keeps the most recently used entries and drops the
/// oldest once it holds `capacity` of them.
public struct RecentCache<Key: Hashable, Value> {
    private let capacity: Int
    private var values: [Key: Value] = [:]
    /// Least recently used first. Linear updates are fine at a few hundred.
    private var order: [Key] = []

    public init(capacity: Int) {
        self.capacity = max(1, capacity)
    }

    public var count: Int { values.count }

    /// The cached value, marked as just used.
    public mutating func value(for key: Key) -> Value? {
        guard let value = values[key] else { return nil }
        touch(key)
        return value
    }

    public mutating func insert(_ value: Value, for key: Key) {
        values[key] = value
        touch(key)
        while order.count > capacity {
            values.removeValue(forKey: order.removeFirst())
        }
    }

    private mutating func touch(_ key: Key) {
        order.removeAll { $0 == key }
        order.append(key)
    }
}

extension RecentCache: Sendable where Key: Sendable, Value: Sendable {}
