//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceStorageInternal
import EmbraceCommonInternal
import OpenTelemetryApi

class SpyLogRepository: LogRepository {

    var didCallFetchAll = false
    var stubbedFetchAllResult: [LogRecord] = []
    func fetchAll(excludingProcessIdentifier processIdentifier: ProcessIdentifier) -> [LogRecord] {
        didCallFetchAll = true
        return stubbedFetchAllResult
    }

    var didCallRemoveLogs = false
    func remove(logs: [LogRecord]) {
        didCallRemoveLogs = true
    }

    var didCallRemoveAllLogs = false
    func removeAllLogs() {
        didCallRemoveAllLogs = true
    }

    var didCallCreate = false
    func createLog(
        id: LogIdentifier,
        processId: ProcessIdentifier,
        severity: LogSeverity,
        body: String,
        timestamp: Date,
        attributes: [String : AttributeValue]
    ) -> LogRecord {
        didCallCreate = true

        return LogRecord(
            id: id,
            processId: processId,
            severity: severity,
            body: body,
            timestamp: timestamp,
            attributes: attributes
        )
    }
}
