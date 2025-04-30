//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal
import EmbraceOTelInternal
import EmbraceStorageInternal
import EmbraceSemantics
import OpenTelemetryApi
import OpenTelemetrySdk

class StorageEmbraceLogExporter: LogRecordExporter {

    @ThreadSafe
    private(set) var state: State
    private let logBatcher: LogBatcher
    private let validation: LogDataValidation

    enum State {
        case active
        case inactive
    }

    init(logBatcher: LogBatcher, state: State = .active, validators: [LogDataValidator] = .default) {
        self.state = state
        self.logBatcher = logBatcher
        self.validation = LogDataValidation(validators: validators)
    }

    func export(logRecords: [ReadableLogRecord], explicitTimeout: TimeInterval?) -> ExportResult {
        guard state == .active else {
            return .failure
        }

        for var log in logRecords where validation.execute(log: &log) {

            // do not export crash logs
            guard !log.isEmbType(LogType.crash) else {
                continue
            }

            self.logBatcher.addLogRecord(logRecord: log)
        }

        return .success
    }

    func shutdown(explicitTimeout: TimeInterval?) {
        state = .inactive
    }

    /// Everything is always persisted on disk, so calling this method has no effect at all.
    /// - Returns: `ExportResult.success`
    func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult {
        .success
    }
}
