//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// Wrapper around `os_unfair_lock` as the direct usage of the API would create
/// crashes due to how Swift's memory model works.
///
/// For more information: 
/// - Swift law of exclusivity: https://github.com/apple/swift-evolution/blob/main/proposals/0176-enforce-exclusive-access-to-memory.md
final public class UnfairLock<Value> {
    private var _lock: UnsafeMutablePointer<os_unfair_lock>
    private var _value: Value
    
    public init(_ value: Value = ()) {
        _lock = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
        _lock.initialize(to: os_unfair_lock())
        _value = value
    }

    deinit {
        _lock.deallocate()
    }

    public func locked<ReturnValue>(_ f: () throws -> ReturnValue) rethrows -> ReturnValue {
        os_unfair_lock_lock(_lock)
        defer { os_unfair_lock_unlock(_lock) }
        return try f()
    }
    
    public func withLock<ReturnValue>(_ f: (inout Value) throws -> ReturnValue) rethrows -> ReturnValue {
        os_unfair_lock_lock(_lock)
        defer { os_unfair_lock_unlock(_lock) }
        return try f(&_value)
    }
}
