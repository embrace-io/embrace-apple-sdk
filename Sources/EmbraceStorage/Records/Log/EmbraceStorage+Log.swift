//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import GRDB
import EmbraceCommon

extension LogRecord: Identifiable {
    public var id: String {
        identifier.value.uuidString
    }
}

extension EmbraceStorage {
    @discardableResult public func addLog(
        id: LogIdentifier,
        processIdentifier: ProcessIdentifier,
        severity: LogSeverity,
        body: String,
        attributes: [String: PersistableValue],
        timestamp: Date = Date()
    ) throws -> LogRecord {
        let log = LogRecord(
            identifier: id,
            processIdentifier: processIdentifier,
            severity: severity,
            body: body,
            attributes: attributes,
            timestamp: timestamp
        )

        try writeLog(log)

        return log
    }

    func writeLog(_ log: LogRecord) throws {
        try dbQueue.write { db in
            try log.insert(db)
        }
    }
}

extension EmbraceStorage: LogRepository {
    public func fetchAll(excludingProcessIdentifier processIdentifier: ProcessIdentifier) throws -> [LogRecord] {
        return try dbQueue.read { db in
            let query = LogRecord.filter(LogRecord.Schema.processIdentifier != processIdentifier.value)
            return try LogRecord.fetchAll(db, query)
        }
    }

    public func removeAllLogs() throws {
        try dbQueue.write { db in
            _ = try LogRecord.deleteAll(db)
        }
    }

    public func remove(logs: [LogRecord]) throws {
        try dbQueue.write { db in
            let logIds = logs.map { $0.id }
            _ = try LogRecord.filter(
                logIds.contains(LogRecord.Schema.identifier)
            ).deleteAll(db)
        }
    }

    public func getAll() throws -> [LogRecord] {
        try dbQueue.read { db in
            try LogRecord.fetchAll(db)
        }
    }

    public func create(_ log: LogRecord, completion: (Result<LogRecord, Error>) -> Void) {
        do {
            try writeLog(log)
            completion(.success(log))
        } catch let exception {
            completion(.failure(exception))
        }
    }
}
