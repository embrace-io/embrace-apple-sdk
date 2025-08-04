//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

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

    func fetchLogRecord(id: String, processId: String) -> LogRecord? {
        let request = LogRecord.createFetchRequest()
        request.predicate = NSPredicate(format: "idRaw == %@ AND processIdRaw == %@", id, processId)

        return coreData.fetch(withRequest: request).first
    }

    public func fetchAll(excludingProcessIdentifier processIdentifier: ProcessIdentifier) -> [EmbraceLog] {
        let request = LogRecord.createFetchRequest()
        request.predicate = NSPredicate(format: "processIdRaw != %@", processIdentifier.value)

        // fetch
        var result: [EmbraceLog] = []
        coreData.fetchAndPerform(withRequest: request) { records in

            // convert to immutable structs
            result = records.map {
                $0.toImmutable()
            }
        }

        return result
    }

    public func removeAllLogs() {
        let records: [LogRecord] = fetchAll()
        coreData.deleteRecords(records)
    }

    public func remove(logs: [EmbraceLog]) {
        var records: [LogRecord] = []

        for log in logs {
            if let record = fetchLogRecord(id: log.idRaw, processId: log.processIdRaw) {
                records.append(record)
            }
        }

        coreData.deleteRecords(records)
    }
}
