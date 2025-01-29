//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal
import OpenTelemetryApi

public protocol LogRepository {
    func create(
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

    public func create(
        id: LogIdentifier,
        processId: ProcessIdentifier,
        severity: LogSeverity,
        body: String,
        timestamp: Date,
        attributes: [String : OpenTelemetryApi.AttributeValue]
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
        remove(logs: getAll())
    }

    public func remove(logs: [LogRecord]) {
        coreData.deleteRecords(logs)
    }

    public func getAll() -> [LogRecord] {
        let request = LogRecord.createFetchRequest()
        return coreData.fetch(withRequest: request)
    }
}
