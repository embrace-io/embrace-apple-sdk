//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetrySdk
import EmbraceCommon
import EmbraceStorage
import Foundation

class EmbraceLogRecordProcessor: LogRecordProcessor {
    @ThreadSafe private(set) var state: State
    private let logBatcher: LogBatcher
    private let exporters: [LogRecordExporter]

    private init(exporters: [LogRecordExporter],
                 logBatcher: LogBatcher,
                 logLimits: LogLimits,
                 state: State = .active) {
        self.state = state
        self.logBatcher = logBatcher
        self.exporters = exporters
    }

    func onEmit(logRecord: ReadableLogRecord) {
        guard state == .active else {
            return
        }
        logBatcher.addLogRecord(logRecord: logRecord)
    }

    /// We're not allowing flushing at the moment. This won't do anything
    /// - Returns: `.failure` as there's no flushing being done.
    func forceFlush() -> ExportResult {
        .failure
    }

    func shutdown() -> ExportResult {
        state = .inactive
        return .success
    }

    func updatedConfig(_ loggerConfig: any EmbraceLoggerConfig) {
        logBatcher.updateLimits(BatchLimits.from(loggerConfig: loggerConfig))
    }
}

extension EmbraceLogRecordProcessor: LogBatcherDelegate {
    func didChangeState(batch: LogBatch) {
        if batch.state == .closed {
            exporters.forEach {
                _ = $0.export(logRecords: batch.logs)
            }
        }
    }
}

extension EmbraceLogRecordProcessor {
    enum State {
        case active
        case inactive
    }
}
