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
    ) -> EmbraceLog?
    func fetchAll(excludingProcessIdentifier processIdentifier: ProcessIdentifier) -> [EmbraceLog]
    func remove(logs: [EmbraceLog])
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
    ) -> EmbraceLog? {
        if let log = LogRecord.create(
            context: coreData.context,
            id: id,
            processId: processId,
            severity: severity,
            body: body,
            timestamp: timestamp,
            attributes: attributes
        ) {
            coreData.save()
            return log
        }

        return nil
    }

    public func fetchAll(excludingProcessIdentifier processIdentifier: ProcessIdentifier) -> [EmbraceLog] {
        let request = LogRecord.createFetchRequest()
        request.predicate = NSPredicate(format: "processIdRaw != %@", processIdentifier.hex)

        return coreData.fetch(withRequest: request)
    }

    public func removeAllLogs() {
        let logs: [LogRecord] = fetchAll()
        remove(logs: logs)
    }

    public func remove(logs: [EmbraceLog]) {
        let records = logs.compactMap({ $0 as? LogRecord })
        coreData.deleteRecords(records)
    }
}
