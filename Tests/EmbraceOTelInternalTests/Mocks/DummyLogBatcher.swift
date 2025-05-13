//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

@testable import EmbraceCore
import EmbraceCommonInternal
import OpenTelemetrySdk

class DummyLogBatcher: LogBatcher {
    func addLogRecord(logRecord: ReadableLogRecord) {
    }

    func renewBatch(withLogs logRecords: [any EmbraceLog]) {
    }

    func forceEndCurrentBatch(waitUntilFinished: Bool) {
    }
}
