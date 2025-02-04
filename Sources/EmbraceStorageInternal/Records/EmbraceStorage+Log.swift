//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal
import OpenTelemetryApi

public protocol LogRepository {
    func createLog(
        id: LogIdentifier,
        processId: ProcessIdentifier,
        severity: LogSeverity,
        body: String,
        timestamp: Date,
        attributes: [String: AttributeValue]
    ) -> LogRecord
    func fetchAll(excludingProcessIdentifier processIdentifier: ProcessIdentifier) -> [LogRecord]
    func remove(logs: [LogRecord])
    func removeAllLogs()
}

extension EmbraceStorage {

    @discardableResult
    public func createLog(
        id: LogIdentifier,
        processId: ProcessIdentifier,
        severity: LogSeverity,
        body: String,
        timestamp: Date = Date(),
        attributes: [String: OpenTelemetryApi.AttributeValue]
    ) -> LogRecord {
        return LogRecord.create(
            context: coreData.context,
            id: id,
            processId: processId,
            severity: severity,
            body: body,
            timestamp: timestamp,
            attributes: attributes
        )
    }

    public func fetchAll(excludingProcessIdentifier processIdentifier: ProcessIdentifier) -> [LogRecord] {
        let request = LogRecord.createFetchRequest()
        request.predicate = NSPredicate(format: "processIdRaw != %@", processIdentifier.hex)

        return coreData.fetch(withRequest: request)
    }

    public func removeAllLogs() {
        let logs: [LogRecord] = fetchAll()
        remove(logs: logs)
    }

    public func remove(logs: [LogRecord]) {
        coreData.deleteRecords(logs)
    }
}
