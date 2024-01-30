//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceStorage

protocol LogRepository {
    func createBatch(completion: @escaping (Result<LogBatch, Error>) -> Void)

    func getBatch(byId batchId: BatchId, completion: @escaping (Result<LogBatch, Error>) -> Void)

    func addLogToBatch(
        withId batchId: BatchId,
        log: ReadableLogRecord,
        completion: @escaping (Result<LogBatch, Error>) -> Void
    )

    func updateStateToBatch(
        withId batchId: BatchId,
        state: LogBatch.State,
        completion: @escaping (Result<LogBatch, Error>) -> Void
    )

    func getPendingBatches(completion: @escaping (Result<[LogBatch], Error>) -> Void)
}
