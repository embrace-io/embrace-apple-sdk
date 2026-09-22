//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// A property wrapper that serializes all access to its value behind an `NSLock`.
///
/// Test doubles routinely capture spans/logs/flags from SDK callbacks that run on background queues
/// while assertions read them on the main thread. Wrapping such stored properties with `@TestLocked`
/// makes those reads/writes thread-safe without hand-rolling a lock + backing var per property
/// (the pattern ThreadSanitizer kept flagging across our mocks).
///
/// The `_modify` accessor holds the lock across in-place mutations, so read-modify-write — e.g.
/// `someLockedArray.append(x)` — stays atomic, not a racy get-copy-append-set.
@propertyWrapper
public final class TestLocked<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value

    public init(wrappedValue: Value) {
        self.value = wrappedValue
    }

    public var wrappedValue: Value {
        get {
            lock.lock()
            defer { lock.unlock() }
            return value
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            value = newValue
        }
        _modify {
            lock.lock()
            defer { lock.unlock() }
            yield &value
        }
    }
}
