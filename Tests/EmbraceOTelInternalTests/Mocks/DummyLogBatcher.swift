//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceSemantics
import EmbraceCommonInternal
import EmbraceConfiguration
import OpenTelemetrySdk

@testable import EmbraceCore

class DummyLogBatcher: LogBatcher {
    var limits = LogsLimits()

    func addLogRecord(logRecord: ReadableLogRecord) {
    }

    func renewBatch(withLogs logRecords: [any EmbraceLog]) {
    }

    func forceEndCurrentBatch(waitUntilFinished: Bool) {
    }
}
