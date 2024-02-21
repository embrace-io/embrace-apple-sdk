//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon
import EmbraceOTel
import EmbraceStorage

class StorageEmbraceLogExporter: EmbraceLogRecordExporter {
    @ThreadSafe
    private(set) var state: State
    private let logBatcher: LogBatcher

    enum State {
        case active
        case inactive
    }

    init(logBatcher: LogBatcher, state: State = .active) {
        self.state = state
        self.logBatcher = logBatcher
    }

    func export(logRecords: [ReadableLogRecord]) -> ExportResult {
        guard state == .active else {
            return .failure
        }
        logRecords.forEach {
            self.logBatcher.addLogRecord(logRecord: buildLogRecord(from: $0))
        }
        return .success
    }

    func shutdown() {
        state = .inactive
    }

    /// Everything is always persisted on disk, so calling this method has no effect at all.
    /// - Returns: `ExportResult.success`
    func forceFlush() -> ExportResult {
        .success
    }
}

private extension StorageEmbraceLogExporter {
    func buildLogRecord(from originalLog: ReadableLogRecord) -> LogRecord {
        .init(
            id: LogIdentifier(),
            timestamp: originalLog.timestamp,
            // Defaulting to `info`. Need to verify if this is appropriate.
            severity: originalLog.severity?.toLogSeverity() ?? .info,
            // Defaulting to an empty string. Need to verify if this is appropriate.
            body: originalLog.body ?? ""
        )
    }
}
