//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// A thread-safe wrapper for properties.
///
/// This property wrapper uses an `UnfairLock` (aka. wrapper around `os_unfair_lock`) to ensure that access
/// to the wrapped property is thread-safe.
/// You can use it to protect properties that might be accessed from multiple threads simultaneously.
///
///     class EmbraceClass {
///         @ThreadSafe var threadSafeProperty: Int = 0
///     }
///
/// Keep in mind that the underlying lock is "unfair", meaning that there's no guarantee about the order in which threads acquire the lock.
/// One thread might acquire the lock multiple times in a row while other threads are waiting.
///
/// - Important: Do not use this wrapper for recursive access patterns; it will deadlock.
/// - Note: This is similar to the `atomic` property attribute in Objective-C, it gives thread safe acccess to the
/// pointer, not the contents.
@propertyWrapper
public final class ThreadSafe<Value>: Sendable {
    private let storage: EmbraceMutex<Value>

    public init(wrappedValue: Value) {
        self.storage = EmbraceMutex(wrappedValue)
    }

    public var wrappedValue: Value {
        get {
            storage.withLock { $0 }
        }
        set {
            storage.withLock { $0 = newValue }
        }
    }

    public func modify(_ operation: (inout Value) -> Void) {
        storage.withLock { operation(&$0) }
    }
}
