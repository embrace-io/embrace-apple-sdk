//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

@testable import EmbraceCommonInternal
@testable import EmbraceCore
@testable @_implementationOnly import EmbraceObjCUtilsInternal

class MockURLSessionTaskHandler: NSObject, URLSessionTaskHandler {
    var didInvokeAddData = false
    var receivedData: Data! = nil
    func addData(_ data: Data, dataTask: URLSessionDataTask) {
        didInvokeAddData = true
        receivedData = data
    }

    var shouldHandleTasks = true
    var didInvokeCreate = false
    var createReceivedTask: URLSessionTask?
    func create(task: URLSessionTask) -> Bool {
        didInvokeCreate = true
        createReceivedTask = task

        return shouldHandleTasks
    }

    var didInvokeFinishWithData = false
    var finishWithDataReceivedParameters: (URLSessionTask, Data?, Error?)?
    func finish(task: URLSessionTask, data: Data?, error: (Error)?) {
        didInvokeFinishWithData = true
        finishWithDataReceivedParameters = (task, data, error)
    }

    var finishWithBodySizeReceivedParameters: (URLSessionTask, Int, Error?)?
    var didInvokeFinishWithBodySize = false
    func finish(task: URLSessionTask, bodySize: Int, error: (any Error)?) {
        didInvokeFinishWithBodySize = true
        finishWithBodySizeReceivedParameters = (task, bodySize, error)
    }
}
