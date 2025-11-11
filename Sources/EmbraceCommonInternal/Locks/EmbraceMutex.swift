import Foundation

/// A thread-safe, general-purpose mutual exclusion lock for protecting access to a value.
///
/// `EmbraceMutex` is a drop-in alternative to the `Mutex<Value>` type introduced in iOS 18,
/// and provides mutual exclusion using an underlying `UnfairLock`.
///
/// This type allows safe concurrent access and mutation of a contained value from multiple threads.
/// The `withLock(_:)` method ensures exclusive access for the duration of a critical section.
///
/// This implementation is compatible with all current iOS versions and can be used
/// as a backward-compatible shim for older platforms.
///
/// - Note: This type is `@unchecked Sendable` when the generic `Value` is `Sendable`,
///   meaning the caller is responsible for ensuring safe usage across concurrency domains.
public final class EmbraceMutex<Value>: @unchecked Sendable {

    /// Creates a new mutex-protected wrapper around the given value.
    ///
    /// - Parameter value: The initial value to protect with the mutex.
    public init(_ value: Value) {
        self.storage = value
        self.lock = UnfairLock()
    }

    /// Acquires the lock, executes the given closure with inout access to the protected value, and then releases the lock.
    ///
    /// - Parameter mutate: A closure that receives inout access to the stored value.
    /// - Returns: The result of the closure.
    ///
    /// - Throws: Rethrows any error thrown by the `mutate` closure.
    @discardableResult
    public func withLock<T>(_ mutate: (inout Value) throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try mutate(&storage)
    }

    private let lock: UnfairLock
    private var storage: Value
}

extension EmbraceMutex {

    /// Synchronously gets or sets the protected value using a lock.
    ///
    /// - Warning: This computed property acquires a lock on every access.
    ///            Prefer `withLock(_:)` for batching reads/writes when possible.
    public var safeValue: Value {
        get { withLock { $0 } }
        set { withLock { $0 = newValue } }
    }

    /// Synchronously gets the protected value without using the lock.
    public var unsafeValue: Value {
        storage
    }
}

extension EmbraceMutex where Value: ExpressibleByNilLiteral {

    /// Synchronously gets the value and set container to nil.
    public func takeValue() -> Value {
        withLock {
            let val = $0
            $0 = nil
            return val
        }
    }
}

/// A thread-safe, general-purpose read/write lock for protecting access to a value.
public final class EmbraceReadWriteLock<Value> {

    /// Creates a new mutex-protected wrapper around the given value.
    ///
    /// - Parameter value: The initial value to protect with the mutex.
    public init(_ value: Value) {
        self.storage = value
        self.lock = ReadWriteLock()
    }

    /// Acquires the lock for reading, executes the given closure with inout access to the protected value, and then releases the lock.
    ///
    /// - Parameter mutate: A closure that receives inout access to the stored value.
    /// - Returns: The result of the closure.
    ///
    /// - Throws: Rethrows any error thrown by the `mutate` closure.
    @discardableResult
    public func withReadLock<T>(_ mutate: (Value) throws -> T) rethrows -> T {
        lock.lockForReading()
        defer { lock.unlock() }
        return try mutate(storage)
    }

    /// Acquires the lock for reading, executes the given closure with inout access to the protected value, and then releases the lock.
    ///
    /// - Parameter mutate: A closure that receives inout access to the stored value.
    /// - Returns: The result of the closure.
    ///
    /// - Throws: Rethrows any error thrown by the `mutate` closure.
    @discardableResult
    public func withWriteLock<T>(_ mutate: (inout Value) throws -> T) rethrows -> T {
        lock.lockForWriting()
        defer { lock.unlock() }
        return try mutate(&storage)
    }

    private let lock: ReadWriteLock
    private var storage: Value
}

extension EmbraceReadWriteLock: @unchecked Sendable {}
