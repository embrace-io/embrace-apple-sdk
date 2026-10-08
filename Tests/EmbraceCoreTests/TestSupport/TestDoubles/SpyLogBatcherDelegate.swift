//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceConfiguration
import EmbraceSemantics

@testable import EmbraceCore

class SpyLogBatcherDelegate: LogBatcherDelegate {
    var didCallBatchFinished: Bool = false
    var batchFinishedReceivedSession: EmbraceSession?
    func batchFinished(withLogs logs: [EmbraceLog], session: EmbraceSession?) {
        didCallBatchFinished = true
        batchFinishedReceivedSession = session
    }
}
