import Testing
@testable import PACELauncherCore

struct RecentCacheTests {
    @Test func `the least recently used entry is evicted`() {
        var cache = RecentCache<String, Int>(capacity: 2)
        cache.insert(1, for: "a")
        cache.insert(2, for: "b")
        #expect(cache.value(for: "a") == 1)
        cache.insert(3, for: "c")
        #expect(cache.count == 2)
        #expect(cache.value(for: "b") == nil)
        #expect(cache.value(for: "a") == 1)
        #expect(cache.value(for: "c") == 3)
    }

    @Test func `inserting an existing key replaces it without growing`() {
        var cache = RecentCache<String, Int>(capacity: 2)
        cache.insert(1, for: "a")
        cache.insert(2, for: "a")
        #expect(cache.count == 1)
        #expect(cache.value(for: "a") == 2)
        cache.insert(3, for: "b")
        cache.insert(4, for: "c")
        #expect(cache.value(for: "a") == nil)
    }
}
