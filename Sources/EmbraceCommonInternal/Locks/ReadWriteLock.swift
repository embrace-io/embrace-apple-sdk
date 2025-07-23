//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// Wrapper around `pthread_rwlock_t` as the direct usage of the API would create
/// crashes due to how Swift's memory model works.
///
final public class ReadWriteLock {
    private var _lock: UnsafeMutablePointer<pthread_rwlock_t>

    public init() {
        _lock = UnsafeMutablePointer<pthread_rwlock_t>.allocate(capacity: 1)
        _lock.initialize(to: pthread_rwlock_t())
        pthread_rwlock_init(_lock, nil)
    }

    deinit {
        pthread_rwlock_destroy(_lock)
        _lock.deallocate()
    }

    public func lockForReading() {
        pthread_rwlock_rdlock(_lock)
    }

    public func lockForWriting() {
        pthread_rwlock_wrlock(_lock)
    }

    public func unlock() {
        pthread_rwlock_unlock(_lock)
    }

    public func lockedForReading<ReturnValue>(_ f: () throws -> ReturnValue) rethrows -> ReturnValue {
        lockForReading()
        defer { unlock() }
        return try f()
    }

    public func lockedForWriting<ReturnValue>(_ f: () throws -> ReturnValue) rethrows -> ReturnValue {
        lockForWriting()
        defer { unlock() }
        return try f()
    }
}
