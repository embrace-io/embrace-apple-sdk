//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
@testable import EmbraceCore
@testable import EmbraceCommonInternal

class MockURLSessionTaskHandler: URLSessionTaskHandler {

    var shouldHandleTasks = true

    var didInvokeCreate = false
    var createReceivedTask: URLSessionTask?
    func create(task: URLSessionTask) -> Bool {
        didInvokeCreate = true
        createReceivedTask = task

        return shouldHandleTasks
    }

    var didInvokeFinish = false
    var finishReceivedParameters: (URLSessionTask, Data?, Error?)?
    func finish(task: URLSessionTask, data: Data?, error: (Error)?) {
        didInvokeFinish = true
        finishReceivedParameters = (task, data, error)
    }
}
