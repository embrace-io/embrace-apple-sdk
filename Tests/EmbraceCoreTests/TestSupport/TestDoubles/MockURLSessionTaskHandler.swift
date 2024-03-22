//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
@testable import EmbraceCore
@testable import EmbraceCommon

class MockURLSessionTaskHandler: URLSessionTaskHandler {
    var didInvokeCreate = false
    var createReceivedTask: URLSessionTask?
    func create(task: URLSessionTask) {
        create(task: task, completion: nil)
    }

    func create(task: URLSessionTask, completion: ((Bool) -> Void)?) {
        didInvokeCreate = true
        createReceivedTask = task

        completion?(true)
    }

    var didInvokeFinish = false
    var finishReceivedParameters: (URLSessionTask, Data?, Error?)?
    func finish(task: URLSessionTask, data: Data?, error: (Error)?) {
        didInvokeFinish = true
        finishReceivedParameters = (task, data, error)
    }
}
