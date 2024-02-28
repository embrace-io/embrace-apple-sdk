//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon
import GRDB

public struct LogRecord {
    public var identifier: LogIdentifier
    public var processIdentifier: ProcessIdentifier
    public var severity: LogSeverity
    public var body: String
    public var timestamp: Date
    public var attributes: [String: PersistableValue]

    public init(identifier: LogIdentifier,
                processIdentifier: ProcessIdentifier,
                severity: LogSeverity,
                body: String,
                attributes: [String: PersistableValue],
                timestamp: Date = Date()) {
        self.identifier = identifier
        self.processIdentifier = processIdentifier
        self.severity = severity
        self.body = body
        self.timestamp = timestamp
        self.attributes = attributes
    }
}

extension LogRecord: FetchableRecord, PersistableRecord {
    public static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase
    public static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    public static let persistenceConflictPolicy = PersistenceConflictPolicy(insert: .replace, update: .replace)

    public func encode(to container: inout PersistenceContainer) {
        container[Schema.identifier] = identifier.value.uuidString
        container[Schema.processIdentifier] = processIdentifier.value
        container[Schema.severity] = severity.rawValue
        container[Schema.body] = body
        container[Schema.timestamp] = timestamp
        if let encodedAttributes = try? JSONEncoder().encode(attributes),
           let attributesJsonString = String(data: encodedAttributes, encoding: .utf8) {
            container[Schema.attributes] = attributesJsonString
        } else {
            container[Schema.attributes] = ""
        }
    }

    public init(row: Row) {
        identifier = LogIdentifier(value: row[Schema.identifier])
        processIdentifier = ProcessIdentifier(value: row[Schema.processIdentifier])
        severity = LogSeverity(rawValue: row[Schema.severity]) ?? .info
        body = row[Schema.body]
        timestamp = row[Schema.timestamp]
        if let jsonString = row[Schema.attributes] as? String,
           let data = jsonString.data(using: .utf8),
           let json = try? JSONDecoder().decode([String: PersistableValue].self, from: data) {
            attributes = json
        } else {
            attributes = [:]
        }
    }
}

extension LogRecord: Codable {
    enum CodingKeys: String, CodingKey {
        case identifier, processIdentifier, severity, body, timestamp, attributes
    }
}

extension LogRecord {
    struct Schema {
        static var identifier: Column { Column("identifier") }
        static var processIdentifier: Column { Column("process_identifier") }
        static var severity: Column { Column("severity") }
        static var body: Column { Column("body") }
        static var timestamp: Column { Column("timestamp") }
        static var attributes: Column { Column("attributes") }
    }
}

extension LogRecord: TableRecord {
    public static let databaseTableName: String = "logs"

    internal static func defineTable(db: Database) throws {
        try db.create(table: LogRecord.databaseTableName, options: .ifNotExists) { t in
            t.primaryKey(Schema.identifier.name, .text).notNull()
            t.column(Schema.processIdentifier.name, .integer).notNull()
            t.column(Schema.severity.name, .integer).notNull()
            t.column(Schema.body.name, .text).notNull()
            t.column(Schema.timestamp.name, .datetime).notNull()
            t.column(Schema.attributes.name, .text).notNull()
        }
    }
}
