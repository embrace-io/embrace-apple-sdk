//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
@testable import EmbraceCore
@testable import EmbraceCommonInternal
@testable import EmbraceObjCUtilsInternal

class MockURLSessionTaskHandler: NSObject, URLSessionTaskHandler {
    var didInvokeAddData = false
    func add(_ data: Data, dataTask: URLSessionDataTask) {
        didInvokeAddData = true
    }

    var shouldHandleTasks = true
    var didInvokeCreate = false
    var createReceivedTask: URLSessionTask?
    func create(_ task: URLSessionTask) -> Bool {
        didInvokeCreate = true
        createReceivedTask = task

        return shouldHandleTasks
    }

    var didInvokeFinish = false
    var finishReceivedParameters: (URLSessionTask, Data?, Error?)?
    func finish(_ task: URLSessionTask, data: Data?, error: (Error)?) {
        didInvokeFinish = true
        finishReceivedParameters = (task, data, error)
    }
}
