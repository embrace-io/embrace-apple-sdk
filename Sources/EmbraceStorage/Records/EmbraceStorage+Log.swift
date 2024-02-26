//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import GRDB
import EmbraceCommon

extension EmbraceStorage {
    @discardableResult public func addLog(
        id: LogIdentifier,
        severity: LogSeverity,
        body: String,
        attributes: [String: String],
        timestamp: Date = Date()
    ) throws -> LogRecord {
        let log = LogRecord(
            id: id,
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
    public func create(_ log: LogRecord, completion: (Result<LogRecord, Error>) -> Void) {
        do {
            try writeLog(log)
            completion(.success(log))
        } catch let exception {
            completion(.failure(exception))
        }
    }
}
