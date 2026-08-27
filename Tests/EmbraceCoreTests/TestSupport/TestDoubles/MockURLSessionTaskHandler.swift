//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import XCTest

@testable import EmbraceCommonInternal
@testable import EmbraceCore
@testable import EmbraceObjCUtilsInternal

class MockURLSessionTaskHandler: NSObject, URLSessionTaskHandler {
    private let lock = NSLock()

    private var _didInvokeAddData = false
    var didInvokeAddData: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _didInvokeAddData
    }

    private var _receivedData: Data?
    var receivedData: Data? {
        lock.lock()
        defer { lock.unlock() }
        return _receivedData
    }

    func addData(_ data: Data, dataTask: URLSessionDataTask) {
        lock.lock()
        defer { lock.unlock() }
        _didInvokeAddData = true
        _receivedData = data
    }

    var shouldHandleTasks = true

    private var _didInvokeCreate = false
    var didInvokeCreate: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _didInvokeCreate
    }

    private var _createReceivedTask: URLSessionTask?
    var createReceivedTask: URLSessionTask? {
        lock.lock()
        defer { lock.unlock() }
        return _createReceivedTask
    }

    /// All tasks passed to `create(task:)`, in invocation order. Used by
    /// `verifyCreated(_:)` to handle watchOS's CFNetwork URLProtocol behavior — see
    /// the doc comment there.
    private var _createInvocations: [URLSessionTask] = []
    var createInvocations: [URLSessionTask] {
        lock.lock()
        defer { lock.unlock() }
        return _createInvocations
    }

    func create(task: URLSessionTask) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        _didInvokeCreate = true
        _createReceivedTask = task
        _createInvocations.append(task)
        return shouldHandleTasks
    }

    /// Asserts the handler saw `task` from a `create(task:)` call.
    ///
    /// iOS/tvOS/macOS: `create(task:)` was called exactly once with `task`.
    /// watchOS: `task` appears anywhere in `createInvocations`. CFNetwork's
    /// URLProtocol driver spawns an internal `URLSessionDataTask` on a background
    /// queue when a `URLProtocol` is registered; it hits the swizzled IMP and
    /// produces spurious `create(task:)` calls the test never requested. A queued
    /// `.resume()` from a prior test can also leak across methods. Strict
    /// checking is unsalvageable without dropping URLProtocol-based mocking.
    func verifyCreated(_ task: URLSessionTask, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(didInvokeCreate, "create(task:) was never called", file: file, line: line)
        #if os(watchOS)
            XCTAssertTrue(
                createInvocations.contains(task),
                "createInvocations \(createInvocations) does not contain expected \(task)",
                file: file,
                line: line
            )
        #else
            XCTAssertEqual(createReceivedTask, task, file: file, line: line)
            XCTAssertEqual(
                createInvocations.count,
                1,
                "expected exactly one create invocation on non-watchOS, got \(createInvocations.count): "
                    + "\(createInvocations)",
                file: file,
                line: line
            )
        #endif
    }

    private var _didInvokeFinishWithData = false
    var didInvokeFinishWithData: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _didInvokeFinishWithData
    }

    private var _finishWithDataReceivedParameters: (URLSessionTask, Data?, Error?)?
    var finishWithDataReceivedParameters: (URLSessionTask, Data?, Error?)? {
        lock.lock()
        defer { lock.unlock() }
        return _finishWithDataReceivedParameters
    }

    func finish(task: URLSessionTask, data: Data?, error: (Error)?) {
        lock.lock()
        defer { lock.unlock() }
        _didInvokeFinishWithData = true
        _finishWithDataReceivedParameters = (task, data, error)
    }

    private var _finishWithBodySizeReceivedParameters: (URLSessionTask, Int, Error?)?
    var finishWithBodySizeReceivedParameters: (URLSessionTask, Int, Error?)? {
        lock.lock()
        defer { lock.unlock() }
        return _finishWithBodySizeReceivedParameters
    }

    private var _didInvokeFinishWithBodySize = false
    var didInvokeFinishWithBodySize: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _didInvokeFinishWithBodySize
    }

    func finish(task: URLSessionTask, bodySize: Int, error: (any Error)?) {
        lock.lock()
        defer { lock.unlock() }
        _didInvokeFinishWithBodySize = true
        _finishWithBodySizeReceivedParameters = (task, bodySize, error)
    }
}
