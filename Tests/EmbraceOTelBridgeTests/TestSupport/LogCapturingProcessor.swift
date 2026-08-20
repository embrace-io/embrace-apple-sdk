//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetrySdk

/// Test helper — captures all emitted log records.
class LogCapturingProcessor: LogRecordProcessor {
    private(set) var capturedLogs: [ReadableLogRecord] = []

    func onEmit(logRecord: ReadableLogRecord) {
        capturedLogs.append(logRecord)
    }

    func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult { .success }
    func shutdown(explicitTimeout: TimeInterval?) -> ExportResult { .success }
}
