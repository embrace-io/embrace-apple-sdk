//
//  Copyright © 2025 Embrace Mobile, Inc.
//  All rights reserved.
//

import Foundation

/// Memory ordering semantics for atomic operations.
///
/// These cases mirror the C11/C++11 memory ordering model
/// and control how operations are sequenced relative to other
/// threads and memory accesses.
public enum MemoryOrder {
    /// No ordering constraints: only atomicity is guaranteed.
    case relaxed
    /// Ensure all prior reads are visible before this load.
    case acquire
    /// Ensure all subsequent writes become visible after this store.
    case release
    /// Combined acquire+release semantics.
    case acquireAndRelease
    /// Sequential consistency (the strongest guarantee).
    case sequencialConsistency
}

/// A generic atomic wrapper for types that conform to `EmbraceAtomicType`.
///
/// This class provides lock-free atomic operations backed by C11/C++11
/// atomics underneath. Each instance manages its own storage and is safe
/// to share across threads.
public final class EmbraceAtomic<T: EmbraceAtomicType> {

    /// Pointer to the underlying atomic storage.
    @usableFromInline
    let storage: UnsafeMutablePointer<T.CType>

    /// Initialize a new atomic with an initial value.
    ///
    /// - Parameter initial: The value to initialize the atomic with.
    public init(_ initial: T) {
        storage = UnsafeMutablePointer<T.CType>.allocate(capacity: 1)
        T._init(storage, initial)
    }

    deinit {
        storage.deallocate()
    }

    /// Load the current value.
    ///
    /// - Parameter order: The memory ordering for the load.
    /// - Returns: The current value of the atomic.
    @inlinable
    public func load(order: MemoryOrder = .sequencialConsistency) -> T {
        T._load(storage, order)
    }

    /// Store a new value.
    ///
    /// - Parameters:
    ///   - value: The value to write.
    ///   - order: The memory ordering for the store.
    @inlinable
    public func store(_ value: T, order: MemoryOrder = .sequencialConsistency) {
        T._store(storage, value, order)
    }

    /// Atomically replace the current value with a new one.
    ///
    /// - Parameters:
    ///   - value: The new value to set.
    ///   - order: The memory ordering for the exchange.
    /// - Returns: The previous value.
    @inlinable
    @discardableResult
    public func exchange(_ value: T, order: MemoryOrder = .sequencialConsistency) -> T {
        T._exchange(storage, value, order)
    }

    /// Compare-and-swap operation.
    ///
    /// Attempts to atomically replace the current value with `desired`
    /// if it matches `expected`. On failure, `expected` is updated to the
    /// actual current value.
    ///
    /// - Parameters:
    ///   - expected: The value expected to be present. Updated on failure.
    ///   - desired: The new value to set if comparison succeeds.
    ///   - successOrder: Memory order if the swap succeeds.
    ///   - failureOrder: Memory order if the swap fails.
    /// - Returns: `true` if the swap succeeded, `false` otherwise.
    @inlinable
    @discardableResult
    public func compareExchange(
        expected: inout T,
        desired: T,
        successOrder: MemoryOrder = .sequencialConsistency
    ) -> Bool {
        T._compareExchange(storage, &expected, desired, successOrder, successOrder.failureOrdering())
    }

    /// Compare-and-swap operation.
    ///
    /// Attempts to atomically replace the current value with `desired`
    /// if it matches `expected`.
    ///
    /// - Parameters:
    ///   - expected: The value expected to be present.
    ///   - desired: The new value to set if comparison succeeds.
    ///   - successOrder: Memory order if the swap succeeds.
    ///   - failureOrder: Memory order if the swap fails.
    /// - Returns: `true` if the swap succeeded, `false` otherwise.
    @inlinable
    @discardableResult
    public func compareExchange(
        expected: T,
        desired: T,
        successOrder: MemoryOrder = .sequencialConsistency
    ) -> Bool {
        var expected = expected
        return T._compareExchange(storage, &expected, desired, successOrder, successOrder.failureOrdering())
    }
}

// MARK: - Arithmetic Atomics

extension EmbraceAtomic where T: EmbraceAtomicArithmetic {
    /// Atomically add `delta` to the current value, returning the previous value.
    @inlinable
    @discardableResult
    public func fetchAdd(_ delta: T, order: MemoryOrder = .sequencialConsistency) -> T {
        T._fetchAdd(storage, delta, order)
    }

    /// Atomically subtract `delta` from the current value, returning the previous value.
    @inlinable
    @discardableResult
    public func fetchSub(_ delta: T, order: MemoryOrder = .sequencialConsistency) -> T {
        T._fetchSub(storage, delta, order)
    }
}

// MARK: - Operator Sugar for Arithmetic Atomics

extension EmbraceAtomic where T: EmbraceAtomicArithmetic {
    /// Atomically add `rhs` to the current value (discarding the previous value).
    @inlinable
    public static func += (lhs: EmbraceAtomic<T>, rhs: T) {
        _ = T._fetchAdd(lhs.storage, rhs, .sequencialConsistency)
    }

    /// Atomically subtract `rhs` from the current value (discarding the previous value).
    @inlinable
    public static func -= (lhs: EmbraceAtomic<T>, rhs: T) {
        _ = T._fetchSub(lhs.storage, rhs, .sequencialConsistency)
    }
}

// MARK: - Boolean Atomics

extension EmbraceAtomic where T == Bool {
    /// Atomically toggle the current boolean and return the **new** value.
    ///
    /// Uses a looped CAS to ensure correctness under contention.
    @inlinable
    @discardableResult
    public func toggle(_ order: MemoryOrder = .sequencialConsistency) -> Bool {
        var cur = self.load(order: .acquire)
        while true {
            let nxt = !cur
            var expected = cur
            if T._compareExchange(storage, &expected, nxt, .sequencialConsistency, .acquire) { return nxt }
            cur = expected
        }
    }
}

// MARK: - Literal Conformances

/// Integer-like atomics can be created from integer literals:
/// ```swift
/// let a: EmbraceAtomic<Int32> = 42
/// ```
extension EmbraceAtomic: ExpressibleByIntegerLiteral where T: ExpressibleByIntegerLiteral {
    public typealias IntegerLiteralType = T.IntegerLiteralType
    public convenience init(integerLiteral value: IntegerLiteralType) {
        self.init(T(integerLiteral: value))
    }
}

/// Boolean atomics can be created from boolean literals:
/// ```swift
/// let flag: EmbraceAtomic<Bool> = true
/// ```
extension EmbraceAtomic: ExpressibleByBooleanLiteral where T == Bool {
    public typealias BooleanLiteralType = Bool
    public convenience init(booleanLiteral value: Bool) {
        self.init(value)
    }
}

// MARK: - Protocol Conformances

/// Safe to print/log atomics without surprising non-atomic reads
/// (uses `.seqCst` ordering by default).
extension EmbraceAtomic: CustomStringConvertible {
    public var description: String { String(describing: self.load()) }
}

/// Equatable by value: compares the current values of both atomics.
extension EmbraceAtomic: Equatable where T: Equatable {
    public static func == (lhs: EmbraceAtomic<T>, rhs: EmbraceAtomic<T>) -> Bool {
        lhs.load() == rhs.load()
    }
}

/// Codable: encodes/decodes by value (useful for configs or snapshots).
extension EmbraceAtomic: Codable where T: Codable {
    public convenience init(from decoder: Decoder) throws {
        let value = try T(from: decoder)
        self.init(value)
    }
    public func encode(to encoder: Encoder) throws {
        try self.load().encode(to: encoder)
    }
}

/// Atomics are assumed safe to send across concurrency domains,
/// though correctness is up to the wrapped type.
extension EmbraceAtomic: @unchecked Sendable {}
