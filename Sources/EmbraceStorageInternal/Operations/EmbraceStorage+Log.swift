//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

public protocol LogRepository {
    func createLog(
        id: EmbraceIdentifier,
        sessionId: EmbraceIdentifier?,
        processId: EmbraceIdentifier,
        severity: EmbraceLogSeverity,
        body: String,
        timestamp: Date,
        attributes: [String: String]
    ) -> EmbraceLog?
    func fetchAll(excludingProcessIdentifier processIdentifier: EmbraceIdentifier) -> [EmbraceLog]
    func remove(logs: [EmbraceLog])
    func removeAllLogs()
}

extension EmbraceStorage {

    @discardableResult
    public func createLog(
        id: EmbraceIdentifier,
        sessionId: EmbraceIdentifier?,
        processId: EmbraceIdentifier,
        severity: EmbraceLogSeverity,
        body: String,
        timestamp: Date = Date(),
        attributes: [String: String]
    ) -> EmbraceLog? {
        if let log = LogRecord.create(
            context: coreData.context,
            id: id.stringValue,
            sessionId: sessionId,
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

    func fetchLogRecord(id: String, processId: EmbraceIdentifier) -> LogRecord? {
        let request = LogRecord.createFetchRequest()
        request.predicate = NSPredicate(
            format: "id == %@ AND processIdRaw == %@", id, processId.stringValue)

        return coreData.fetch(withRequest: request).first
    }

    public func fetchAll(excludingProcessIdentifier processIdentifier: EmbraceIdentifier) -> [EmbraceLog] {
        let request = LogRecord.createFetchRequest()
        request.predicate = NSPredicate(format: "processIdRaw != %@", processIdentifier.stringValue)

        // fetch
        var result: [EmbraceLog] = []
        coreData.fetchAndPerform(withRequest: request) { records, _ in

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
            if let record = fetchLogRecord(id: log.id, processId: log.processId) {
                records.append(record)
            }
        }

        coreData.deleteRecords(records)
    }
}
