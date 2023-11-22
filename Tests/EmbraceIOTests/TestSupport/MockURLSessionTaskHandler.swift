//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//
    

import Foundation
@testable import EmbraceIO
@testable import EmbraceCommon

class MockURLSessionTaskHandler: URLSessionTaskHandler {
    var didInvokeCreate = false
    var createReceivedTask: URLSessionTask?
    func create(task: URLSessionTask) {
        didInvokeCreate = true
        createReceivedTask = task
    }

    var didInvokeFinish = false
    func finish(task: URLSessionTask, data: Data?, error: (Error)?) {
        didInvokeFinish = true
    }

    var didInvokeChangedState = false
    func changedState(to collectorState: EmbraceCommon.CollectorState) {
        didInvokeChangedState = true
    }
}
