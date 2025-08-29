//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

class AsyncOperation: Operation, @unchecked Sendable {
    private let lock = ReadWriteLock()

    override var isAsynchronous: Bool {
        return true
    }

    private var _isExecuting: Bool = false
    override private(set) var isExecuting: Bool {
        get {
            lock.lockedForReading { _isExecuting }
        }
        set {
            willChangeValue(forKey: "isExecuting")
            lock.lockedForWriting { _isExecuting = newValue }
            didChangeValue(forKey: "isExecuting")
        }
    }

    private var _isFinished: Bool = false
    override private(set) var isFinished: Bool {
        get {
            lock.lockedForReading { _isFinished }
        }
        set {
            willChangeValue(forKey: "isFinished")
            lock.lockedForWriting { _isFinished = newValue }
            didChangeValue(forKey: "isFinished")
        }
    }

    override func start() {
        guard !isCancelled else {
            finish()
            return
        }

        isFinished = false
        isExecuting = true
        execute()
    }

    func execute() {
        // override
    }

    func finish() {
        isExecuting = false
        isFinished = true
    }
}
