//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal
import EmbraceStorageInternal

struct LogsBatch {
    enum BatchState {
        case open
        case closed
    }

    enum BatchingResult {
        case success(batchState: BatchState)
        case failure
    }

    @ThreadSafe
    private(set) var logs: [LogRecord]
    private let limits: LogBatchLimits

    private var creationDate: Date? {
        logs.sorted(by: { $0.timestamp < $1.timestamp })
            .first?
            .timestamp
    }

    var batchState: BatchState {
        let isBatchFull = logs.count >= limits.maxLogsPerBatch
        let isBatchOld = -(creationDate?.timeIntervalSinceNow ?? 0.0) > limits.maxBatchAge
        if isBatchFull || isBatchOld {
            return .closed
        }
        return .open
    }

    init(limits: LogBatchLimits, logs: [LogRecord] = []) {
        self.logs = logs
        self.limits = limits
    }

    func add(logRecord: LogRecord) -> BatchingResult {
        guard batchState == .open else {
            return .failure
        }
        logs.append(logRecord)
        return .success(batchState: batchState)
    }
}
