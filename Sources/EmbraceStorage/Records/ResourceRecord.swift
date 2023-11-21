//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon
import GRDB

public enum ResourceType: String, Codable {
    case process
    case session
    case permanent
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
        self.collectedAt = collectedAt
    }

    /// Initialize a permanent resource
    /// A permanent resource does not need a resourceTypeId as it is implicit
    /// - Parameters:
    ///     - key: The unique identifier of the permanent resource
    ///     - value: The value of the resource, encoded as a String
    ///     - collectedAt: The date the resource item was collected
    public init(key: String, value: String, collectedAt: Date = Date()) {
        self.init(key: key, value: value, resourceType: .permanent, collectedAt: collectedAt)
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

            t.column("key", .text).notNull()
            t.column("resource_type", .text).notNull()
            t.column("resource_type_id", .text).notNull()
            t.column("value", .text).notNull()
            t.column("collected_at", .datetime).notNull()

            t.primaryKey(["key", "resource_type", "resource_type_id"])
        }
    }
}

extension ResourceRecord: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.key == rhs.key
    }
}
