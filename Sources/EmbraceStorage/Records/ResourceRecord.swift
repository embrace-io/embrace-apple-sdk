//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon
import GRDB

public enum ResourceType: String, Codable {
    case process = "process"
    case session = "session"
    case permanent = "permanent"
}

public struct ResourceRecord: Codable {
    public var resourceType: ResourceType
    public var resourceTypeId: String
    public var key: String
    public var value: String
    public var collectedAt: Date

    public init(key: String, value: String, resourceType: ResourceType, resourceTypeId: String = "N/A", collectedAt: Date = Date()) {
        self.key = key
        self.value = value
        self.resourceType = resourceType
        self.resourceTypeId = resourceTypeId
        self.collectedAt = Date()
    }

    public init(key: String, value: Int, resourceType: ResourceType, resourceTypeId: String = "N/A", collectedAt: Date = Date()) {
        self.key = key
        self.value = String(value)
        self.resourceType = resourceType
        self.resourceTypeId = resourceTypeId
        self.collectedAt = collectedAt
    }

    public init(key: String, value: Double, resourceType: ResourceType, resourceTypeId: String = "N/A", collectedAt: Date = Date()) {
        self.key = key
        self.value = String(value)
        self.resourceType = resourceType
        self.resourceTypeId = resourceTypeId
        self.collectedAt = collectedAt
    }
}

extension ResourceRecord: FetchableRecord, PersistableRecord, MutablePersistableRecord {
    public static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase
    public static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    public static let persistenceConflictPolicy = PersistenceConflictPolicy(insert: .replace, update: .replace)
}

extension ResourceRecord: TableRecord {
    public static let databaseTableName: String = "resources"

    internal static func defineTable(db: Database) throws {
        try db.create(table: ResourceRecord.databaseTableName, options: .ifNotExists) { t in

            t.primaryKey("key", .text).notNull()
            t.column("resource_type", .text).notNull()
            t.column("resource_type_id", .text).notNull()
            t.column("value", .text).notNull()
            t.column("collected_at", .datetime).notNull()
        }
    }
}

extension ResourceRecord: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.key == rhs.key
    }
}
