import Foundation

/// Fixed-capacity ring buffer. Overwrites oldest entries when full.
/// Used to hold the rolling ~1 hour of metric samples.
struct CircularBuffer<Element: Sendable>: Sendable {
    private var storage: [Element?]
    private var head: Int = 0
    private(set) var count: Int = 0
    let capacity: Int

    init(capacity: Int) {
        self.capacity = capacity
        self.storage = Array(repeating: nil, count: capacity)
    }

    mutating func append(_ element: Element) {
        storage[head] = element
        head = (head + 1) % capacity
        if count < capacity { count += 1 }
    }

    /// Returns elements in chronological order (oldest first).
    func toArray() -> [Element] {
        guard count > 0 else { return [] }
        if count < capacity {
            return storage[0..<count].compactMap { $0 }
        }
        let tail = storage[head..<capacity].compactMap { $0 }
        let front = storage[0..<head].compactMap { $0 }
        return tail + front
    }

    var latest: Element? {
        guard count > 0 else { return nil }
        let index = (head - 1 + capacity) % capacity
        return storage[index]
    }
}
