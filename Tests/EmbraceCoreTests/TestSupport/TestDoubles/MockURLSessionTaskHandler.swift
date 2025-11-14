//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

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

    func create(task: URLSessionTask) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        _didInvokeCreate = true
        _createReceivedTask = task
        return shouldHandleTasks
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
