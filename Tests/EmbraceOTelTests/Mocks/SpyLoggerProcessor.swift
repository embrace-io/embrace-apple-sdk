//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
@testable import EmbraceOTel

class SpyLoggerProcessor: EmbraceLogRecordProcessor {
    var receivedLogRecord: ReadableLogRecord?
    var didCallOnEmit = false
    func onEmit(logRecord: ReadableLogRecord) {
        didCallOnEmit = true
        receivedLogRecord = logRecord
    }

    var didCallForceFlush = false
    func forceFlush() -> ExportResult {
        didCallForceFlush = true
        return .success
    }

    var didCallShutdown = false
    func shutdown() -> ExportResult {
        didCallShutdown = true
        return .success
    }
}
