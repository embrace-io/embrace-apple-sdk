//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetrySdk

@testable import EmbraceOTelInternal

class SpyLoggerProcessor: LogRecordProcessor {
    var receivedLogRecord: ReadableLogRecord?
    var didCallOnEmit = false
    func onEmit(logRecord: ReadableLogRecord) {
        didCallOnEmit = true
        receivedLogRecord = logRecord
    }

    var didCallForceFlush = false
    func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult {
        didCallForceFlush = true
        return .success
    }

    var didCallShutdown = false
    func shutdown(explicitTimeout: TimeInterval?) -> ExportResult {
        didCallShutdown = true
        return .success
    }
}
