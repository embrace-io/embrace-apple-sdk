//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
@testable import EmbraceCore
import EmbraceConfiguration

class SpyLogBatcherDelegate: LogBatcherDelegate {
    var didCallBatchFinished: Bool = false
    func batchFinished(withLogs logs: [EmbraceLog]) {
        didCallBatchFinished = true
    }

    var limits = LogsLimits()
}
