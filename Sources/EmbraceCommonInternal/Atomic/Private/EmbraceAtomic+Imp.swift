//
//  Copyright © 2025 Embrace Mobile, Inc.
//  All rights reserved.
//
//  Atomic Type Conformances
//

//  This file defines Swift protocols and type conformances that bridge to the
//  C atomic operations exposed by `EmbraceAtomicsShim`. The goal is to provide
//  a type-safe Swift interface to low-level atomic primitives across integral
//  types and Bool.
//
//  Overview
//  --------
//  • `MemoryOrder` → `EMBAtomicMemoryOrder` mapping keeps memory ordering
//    semantics consistent with the C layer.
//  • `EmbraceAtomicType` specifies the minimal surface for atomic operations
//    (init, load, store, exchange, compareExchange).
//  • `EmbraceAtomicArithmetic` extends that with fetch-add / fetch-sub for
//    arithmetic-capable types.
//  • Concrete Swift types (`Int8/16/32/64`, `UInt8/16/32/64`, `Bool`) conform
//    by delegating to the corresponding C functions (`emb_atomic_*`).
//
//  Notes
//  -----
//  • `CType` is the C wrapper type (usually a struct encapsulating a C11
//    `_Atomic(T)`), not the Swift value type.
//  • All operations accept a `MemoryOrder` which is converted to the C enum.
//  • `Bool` intentionally does not conform to `EmbraceAtomicArithmetic`.
//

import EmbraceAtomicsShim

// MARK: - Memory Order Mapping

/// Bridges Swift `MemoryOrder` into the C enum used by Embrace atomics.
/// If a new enum case appears at runtime (from newer shims), we deliberately
/// crash to avoid silently applying the wrong semantics.
extension MemoryOrder {
    var atomicOrder: EMBAtomicMemoryOrder {
        switch self {
        case .relaxed: return .relaxed
        case .consume: return .consume
        case .acquire: return .acquire
        case .release: return .release
        case .acqRel: return .acqRel
        case .seqCst: return .seqCst
        @unknown default:
            fatalError("Encountered unknown MemoryOrder case")
        }
    }
}

// MARK: - Protocols

/// Core requirements for atomic operations on a Swift type `Self`.
///
/// Conformers provide a `CType` (the C backing type) and forward each method
/// to the corresponding `emb_atomic_*` symbol in `EmbraceAtomicsShim`.
public protocol EmbraceAtomicType: Equatable {
    associatedtype CType

    /// Initialize an atomic at address `a` with `value`.
    static func _init(_ a: UnsafeMutablePointer<CType>, _ value: Self)

    /// Atomically load the current value with the given memory `order`.
    static func _load(_ a: UnsafePointer<CType>, _ order: MemoryOrder) -> Self

    /// Atomically store `value` with the given memory `order`.
    static func _store(_ a: UnsafeMutablePointer<CType>, _ value: Self, _ order: MemoryOrder)

    /// Atomically replace the value with `value` and return the previous value.
    static func _exchange(_ a: UnsafeMutablePointer<CType>, _ value: Self, _ order: MemoryOrder) -> Self

    /// Atomically compare with `*expected` and, if equal, store `desired`.
    /// Returns true on success and updates `expected` on failure.
    static func _compareExchange(
        _ a: UnsafeMutablePointer<CType>,
        _ expected: UnsafeMutablePointer<Self>,
        _ desired: Self,
        _ success: MemoryOrder,
        _ failure: MemoryOrder
    ) -> Bool
}

/// Arithmetic atomics (e.g., integers) that support fetch-add and fetch-sub.
public protocol EmbraceAtomicArithmetic: EmbraceAtomicType {
    /// Atomically add `delta`, returning the previous value.
    static func _fetchAdd(_ a: UnsafeMutablePointer<CType>, _ delta: Self, _ order: MemoryOrder) -> Self

    /// Atomically subtract `delta`, returning the previous value.
    static func _fetchSub(_ a: UnsafeMutablePointer<CType>, _ delta: Self, _ order: MemoryOrder) -> Self
}

// MARK: - Type Conformances
//
// Each primitive type below implements the required methods by delegating to
// the C functions exposed by `EmbraceAtomicsShim`.

// MARK: Int8
extension Int8: EmbraceAtomicArithmetic {
    public typealias CType = emb_atomic_int8_t
    public static func _init(_ a: UnsafeMutablePointer<CType>, _ value: Int8) {
        emb_atomic_int8_init(a, value)
    }
    public static func _load(_ a: UnsafePointer<CType>, _ order: MemoryOrder) -> Int8 {
        emb_atomic_int8_load(a, order.atomicOrder)
    }
    public static func _store(_ a: UnsafeMutablePointer<CType>, _ value: Int8, _ order: MemoryOrder) {
        emb_atomic_int8_store(a, value, order.atomicOrder)
    }
    public static func _exchange(_ a: UnsafeMutablePointer<CType>, _ value: Int8, _ order: MemoryOrder) -> Int8 {
        emb_atomic_int8_exchange(a, value, order.atomicOrder)
    }
    public static func _compareExchange(
        _ a: UnsafeMutablePointer<CType>,
        _ expected: UnsafeMutablePointer<Int8>,
        _ desired: Int8,
        _ success: MemoryOrder,
        _ failure: MemoryOrder
    ) -> Bool {
        emb_atomic_int8_compare_exchange(a, expected, desired, success.atomicOrder, failure.atomicOrder)
    }
    public static func _fetchAdd(_ a: UnsafeMutablePointer<CType>, _ delta: Int8, _ order: MemoryOrder) -> Int8 {
        emb_atomic_int8_fetch_add(a, delta, order.atomicOrder)
    }
    public static func _fetchSub(_ a: UnsafeMutablePointer<CType>, _ delta: Int8, _ order: MemoryOrder) -> Int8 {
        emb_atomic_int8_fetch_sub(a, delta, order.atomicOrder)
    }
}

// MARK: Int16
extension Int16: EmbraceAtomicArithmetic {
    public typealias CType = emb_atomic_int16_t
    public static func _init(_ a: UnsafeMutablePointer<CType>, _ value: Int16) {
        emb_atomic_int16_init(a, value)
    }
    public static func _load(_ a: UnsafePointer<CType>, _ order: MemoryOrder) -> Int16 {
        emb_atomic_int16_load(a, order.atomicOrder)
    }
    public static func _store(_ a: UnsafeMutablePointer<CType>, _ value: Int16, _ order: MemoryOrder) {
        emb_atomic_int16_store(a, value, order.atomicOrder)
    }
    public static func _exchange(_ a: UnsafeMutablePointer<CType>, _ value: Int16, _ order: MemoryOrder) -> Int16 {
        emb_atomic_int16_exchange(a, value, order.atomicOrder)
    }
    public static func _compareExchange(
        _ a: UnsafeMutablePointer<CType>,
        _ expected: UnsafeMutablePointer<Int16>,
        _ desired: Int16,
        _ success: MemoryOrder,
        _ failure: MemoryOrder
    ) -> Bool {
        emb_atomic_int16_compare_exchange(a, expected, desired, success.atomicOrder, failure.atomicOrder)
    }
    public static func _fetchAdd(_ a: UnsafeMutablePointer<CType>, _ delta: Int16, _ order: MemoryOrder) -> Int16 {
        emb_atomic_int16_fetch_add(a, delta, order.atomicOrder)
    }
    public static func _fetchSub(_ a: UnsafeMutablePointer<CType>, _ delta: Int16, _ order: MemoryOrder) -> Int16 {
        emb_atomic_int16_fetch_sub(a, delta, order.atomicOrder)
    }
}

// MARK: Int32
extension Int32: EmbraceAtomicArithmetic {
    public typealias CType = emb_atomic_int32_t
    public static func _init(_ a: UnsafeMutablePointer<CType>, _ value: Int32) {
        emb_atomic_int32_init(a, value)
    }
    public static func _load(_ a: UnsafePointer<CType>, _ order: MemoryOrder) -> Int32 {
        emb_atomic_int32_load(a, order.atomicOrder)
    }
    public static func _store(_ a: UnsafeMutablePointer<CType>, _ value: Int32, _ order: MemoryOrder) {
        emb_atomic_int32_store(a, value, order.atomicOrder)
    }
    public static func _exchange(_ a: UnsafeMutablePointer<CType>, _ value: Int32, _ order: MemoryOrder) -> Int32 {
        emb_atomic_int32_exchange(a, value, order.atomicOrder)
    }
    public static func _compareExchange(
        _ a: UnsafeMutablePointer<CType>,
        _ expected: UnsafeMutablePointer<Int32>,
        _ desired: Int32,
        _ success: MemoryOrder,
        _ failure: MemoryOrder
    ) -> Bool {
        emb_atomic_int32_compare_exchange(a, expected, desired, success.atomicOrder, failure.atomicOrder)
    }
    public static func _fetchAdd(_ a: UnsafeMutablePointer<CType>, _ delta: Int32, _ order: MemoryOrder) -> Int32 {
        emb_atomic_int32_fetch_add(a, delta, order.atomicOrder)
    }
    public static func _fetchSub(_ a: UnsafeMutablePointer<CType>, _ delta: Int32, _ order: MemoryOrder) -> Int32 {
        emb_atomic_int32_fetch_sub(a, delta, order.atomicOrder)
    }
}

// MARK: Int64
extension Int64: EmbraceAtomicArithmetic {
    public typealias CType = emb_atomic_int64_t
    public static func _init(_ a: UnsafeMutablePointer<CType>, _ value: Int64) {
        emb_atomic_int64_init(a, value)
    }
    public static func _load(_ a: UnsafePointer<CType>, _ order: MemoryOrder) -> Int64 {
        emb_atomic_int64_load(a, order.atomicOrder)
    }
    public static func _store(_ a: UnsafeMutablePointer<CType>, _ value: Int64, _ order: MemoryOrder) {
        emb_atomic_int64_store(a, value, order.atomicOrder)
    }
    public static func _exchange(_ a: UnsafeMutablePointer<CType>, _ value: Int64, _ order: MemoryOrder) -> Int64 {
        emb_atomic_int64_exchange(a, value, order.atomicOrder)
    }
    public static func _compareExchange(
        _ a: UnsafeMutablePointer<CType>,
        _ expected: UnsafeMutablePointer<Int64>,
        _ desired: Int64,
        _ success: MemoryOrder,
        _ failure: MemoryOrder
    ) -> Bool {
        emb_atomic_int64_compare_exchange(a, expected, desired, success.atomicOrder, failure.atomicOrder)
    }
    public static func _fetchAdd(_ a: UnsafeMutablePointer<CType>, _ delta: Int64, _ order: MemoryOrder) -> Int64 {
        emb_atomic_int64_fetch_add(a, delta, order.atomicOrder)
    }
    public static func _fetchSub(_ a: UnsafeMutablePointer<CType>, _ delta: Int64, _ order: MemoryOrder) -> Int64 {
        emb_atomic_int64_fetch_sub(a, delta, order.atomicOrder)
    }
}

// MARK: UInt8
extension UInt8: EmbraceAtomicArithmetic {
    public typealias CType = emb_atomic_uint8_t
    public static func _init(_ a: UnsafeMutablePointer<CType>, _ value: UInt8) {
        emb_atomic_uint8_init(a, value)
    }
    public static func _load(_ a: UnsafePointer<CType>, _ order: MemoryOrder) -> UInt8 {
        emb_atomic_uint8_load(a, order.atomicOrder)
    }
    public static func _store(_ a: UnsafeMutablePointer<CType>, _ value: UInt8, _ order: MemoryOrder) {
        emb_atomic_uint8_store(a, value, order.atomicOrder)
    }
    public static func _exchange(_ a: UnsafeMutablePointer<CType>, _ value: UInt8, _ order: MemoryOrder) -> UInt8 {
        emb_atomic_uint8_exchange(a, value, order.atomicOrder)
    }
    public static func _compareExchange(
        _ a: UnsafeMutablePointer<CType>,
        _ expected: UnsafeMutablePointer<UInt8>,
        _ desired: UInt8,
        _ success: MemoryOrder,
        _ failure: MemoryOrder
    ) -> Bool {
        emb_atomic_uint8_compare_exchange(a, expected, desired, success.atomicOrder, failure.atomicOrder)
    }
    public static func _fetchAdd(_ a: UnsafeMutablePointer<CType>, _ delta: UInt8, _ order: MemoryOrder) -> UInt8 {
        emb_atomic_uint8_fetch_add(a, delta, order.atomicOrder)
    }
    public static func _fetchSub(_ a: UnsafeMutablePointer<CType>, _ delta: UInt8, _ order: MemoryOrder) -> UInt8 {
        emb_atomic_uint8_fetch_sub(a, delta, order.atomicOrder)
    }
}

// MARK: UInt16
extension UInt16: EmbraceAtomicArithmetic {
    public typealias CType = emb_atomic_uint16_t
    public static func _init(_ a: UnsafeMutablePointer<CType>, _ value: UInt16) {
        emb_atomic_uint16_init(a, value)
    }
    public static func _load(_ a: UnsafePointer<CType>, _ order: MemoryOrder) -> UInt16 {
        emb_atomic_uint16_load(a, order.atomicOrder)
    }
    public static func _store(_ a: UnsafeMutablePointer<CType>, _ value: UInt16, _ order: MemoryOrder) {
        emb_atomic_uint16_store(a, value, order.atomicOrder)
    }
    public static func _exchange(_ a: UnsafeMutablePointer<CType>, _ value: UInt16, _ order: MemoryOrder) -> UInt16 {
        emb_atomic_uint16_exchange(a, value, order.atomicOrder)
    }
    public static func _compareExchange(
        _ a: UnsafeMutablePointer<CType>,
        _ expected: UnsafeMutablePointer<UInt16>,
        _ desired: UInt16,
        _ success: MemoryOrder,
        _ failure: MemoryOrder
    ) -> Bool {
        emb_atomic_uint16_compare_exchange(a, expected, desired, success.atomicOrder, failure.atomicOrder)
    }
    public static func _fetchAdd(_ a: UnsafeMutablePointer<CType>, _ delta: UInt16, _ order: MemoryOrder) -> UInt16 {
        emb_atomic_uint16_fetch_add(a, delta, order.atomicOrder)
    }
    public static func _fetchSub(_ a: UnsafeMutablePointer<CType>, _ delta: UInt16, _ order: MemoryOrder) -> UInt16 {
        emb_atomic_uint16_fetch_sub(a, delta, order.atomicOrder)
    }
}

// MARK: UInt32
extension UInt32: EmbraceAtomicArithmetic {
    public typealias CType = emb_atomic_uint32_t
    public static func _init(_ a: UnsafeMutablePointer<CType>, _ value: UInt32) {
        emb_atomic_uint32_init(a, value)
    }
    public static func _load(_ a: UnsafePointer<CType>, _ order: MemoryOrder) -> UInt32 {
        emb_atomic_uint32_load(a, order.atomicOrder)
    }
    public static func _store(_ a: UnsafeMutablePointer<CType>, _ value: UInt32, _ order: MemoryOrder) {
        emb_atomic_uint32_store(a, value, order.atomicOrder)
    }
    public static func _exchange(_ a: UnsafeMutablePointer<CType>, _ value: UInt32, _ order: MemoryOrder) -> UInt32 {
        emb_atomic_uint32_exchange(a, value, order.atomicOrder)
    }
    public static func _compareExchange(
        _ a: UnsafeMutablePointer<CType>,
        _ expected: UnsafeMutablePointer<UInt32>,
        _ desired: UInt32,
        _ success: MemoryOrder,
        _ failure: MemoryOrder
    ) -> Bool {
        emb_atomic_uint32_compare_exchange(a, expected, desired, success.atomicOrder, failure.atomicOrder)
    }
    public static func _fetchAdd(_ a: UnsafeMutablePointer<CType>, _ delta: UInt32, _ order: MemoryOrder) -> UInt32 {
        emb_atomic_uint32_fetch_add(a, delta, order.atomicOrder)
    }
    public static func _fetchSub(_ a: UnsafeMutablePointer<CType>, _ delta: UInt32, _ order: MemoryOrder) -> UInt32 {
        emb_atomic_uint32_fetch_sub(a, delta, order.atomicOrder)
    }
}

// MARK: UInt64
extension UInt64: EmbraceAtomicArithmetic {
    public typealias CType = emb_atomic_uint64_t
    public static func _init(_ a: UnsafeMutablePointer<CType>, _ value: UInt64) {
        emb_atomic_uint64_init(a, value)
    }
    public static func _load(_ a: UnsafePointer<CType>, _ order: MemoryOrder) -> UInt64 {
        emb_atomic_uint64_load(a, order.atomicOrder)
    }
    public static func _store(_ a: UnsafeMutablePointer<CType>, _ value: UInt64, _ order: MemoryOrder) {
        emb_atomic_uint64_store(a, value, order.atomicOrder)
    }
    public static func _exchange(_ a: UnsafeMutablePointer<CType>, _ value: UInt64, _ order: MemoryOrder) -> UInt64 {
        emb_atomic_uint64_exchange(a, value, order.atomicOrder)
    }
    public static func _compareExchange(
        _ a: UnsafeMutablePointer<CType>,
        _ expected: UnsafeMutablePointer<UInt64>,
        _ desired: UInt64,
        _ success: MemoryOrder,
        _ failure: MemoryOrder
    ) -> Bool {
        emb_atomic_uint64_compare_exchange(a, expected, desired, success.atomicOrder, failure.atomicOrder)
    }
    public static func _fetchAdd(_ a: UnsafeMutablePointer<CType>, _ delta: UInt64, _ order: MemoryOrder) -> UInt64 {
        emb_atomic_uint64_fetch_add(a, delta, order.atomicOrder)
    }
    public static func _fetchSub(_ a: UnsafeMutablePointer<CType>, _ delta: UInt64, _ order: MemoryOrder) -> UInt64 {
        emb_atomic_uint64_fetch_sub(a, delta, order.atomicOrder)
    }
}

// MARK: Bool (no arithmetic)
extension Bool: EmbraceAtomicType {
    public typealias CType = emb_atomic_bool_t
    public static func _init(_ a: UnsafeMutablePointer<CType>, _ value: Bool) {
        emb_atomic_bool_init(a, value)
    }
    public static func _load(_ a: UnsafePointer<CType>, _ order: MemoryOrder) -> Bool {
        emb_atomic_bool_load(a, order.atomicOrder)
    }
    public static func _store(_ a: UnsafeMutablePointer<CType>, _ value: Bool, _ order: MemoryOrder) {
        emb_atomic_bool_store(a, value, order.atomicOrder)
    }
    public static func _exchange(_ a: UnsafeMutablePointer<CType>, _ value: Bool, _ order: MemoryOrder) -> Bool {
        emb_atomic_bool_exchange(a, value, order.atomicOrder)
    }
    public static func _compareExchange(
        _ a: UnsafeMutablePointer<CType>,
        _ expected: UnsafeMutablePointer<Bool>,
        _ desired: Bool,
        _ success: MemoryOrder,
        _ failure: MemoryOrder
    ) -> Bool {
        emb_atomic_bool_compare_exchange(a, expected, desired, success.atomicOrder, failure.atomicOrder)
    }
}
