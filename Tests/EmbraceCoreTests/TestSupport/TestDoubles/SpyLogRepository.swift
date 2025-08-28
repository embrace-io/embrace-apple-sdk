//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceStorageInternal
import Foundation
import OpenTelemetryApi
import TestSupport
import EmbraceSemantics

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
        sessionId: EmbraceIdentifier?,
        processId: EmbraceIdentifier,
        severity: EmbraceLogSeverity,
        type: EmbraceType,
        body: String,
        timestamp: Date,
        attributes: [String: String]
    ) -> EmbraceLog? {
        didCallCreate = true

        return MockLog(
            id: id.stringValue,
            severity: severity,
            type: type,
            timestamp: timestamp,
            body: body,
            sessionId: sessionId,
            processId: processId,
            attributes: attributes
        )
    }
}
