//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceStorageInternal
import Foundation
import OpenTelemetryApi
import TestSupport

class SpyLogRepository: LogRepository {

    var didCallFetchAll = false
    var stubbedFetchAllResult: [EmbraceLog] = []
    func fetchAll(excludingProcessIdentifier processIdentifier: EmbraceIdentifier) -> [EmbraceLog] {
        didCallFetchAll = true
        return stubbedFetchAllResult
    }

    var didCallRemoveLogs = false
    func remove(logs: [EmbraceLog]) {
        didCallRemoveLogs = true
    }

    var didCallRemoveAllLogs = false
    func removeAllLogs() {
        didCallRemoveAllLogs = true
    }

    var didCallCreate = false
    func createLog(
        id: EmbraceIdentifier,
        processId: EmbraceIdentifier,
        severity: LogSeverity,
        body: String,
        timestamp: Date,
        attributes: [String: AttributeValue]
    ) -> EmbraceLog? {
        didCallCreate = true

        return MockLog(
            id: id,
            processId: processId,
            severity: severity,
            body: body,
            timestamp: timestamp,
            attributes: attributes
        )
    }
}
