//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceConfiguration
import EmbraceSemantics

@testable import EmbraceCore

class SpyLogBatcherDelegate: LogBatcherDelegate {
    var didCallBatchFinished: Bool = false
    func batchFinished(withLogs logs: [EmbraceLog]) {
        didCallBatchFinished = true
    }

    var limits = LogsLimits()

    var currentSessionId: EmbraceIdentifier?
}
