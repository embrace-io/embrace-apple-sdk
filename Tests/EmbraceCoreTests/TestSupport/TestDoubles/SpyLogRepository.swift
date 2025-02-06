//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceStorageInternal
import EmbraceCommonInternal

class SpyLogRepository: LogRepository {
    var didCallFetchAll = false
    var stubbedFetchAllResult: [LogRecord] = []
    func fetchAll(excludingProcessIdentifier processIdentifier: ProcessIdentifier) throws -> [LogRecord] {
        didCallFetchAll = true
        return stubbedFetchAllResult
    }

    var didCallRemoveLogs = false
    func remove(logs: [LogRecord]) throws {
        didCallRemoveLogs = true
    }

    var didCallRemoveAllLogs = false
    func removeAllLogs() throws {
        didCallRemoveAllLogs = true
    }

    var didCallCreate: Bool = false
    var stubbedCreateCompletionResult: (Result<LogRecord, Error>)?
    func create(_ log: LogRecord, completion: (Result<LogRecord, Error>) -> Void) {
        didCallCreate = true
        if let result = stubbedCreateCompletionResult {
            completion(result)
        }
    }
}
