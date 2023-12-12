//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon
import GRDB
import OpenTelemetryApi

public enum ResourceType: String, Codable {
    /// value tied to a specific session
    case session

    /// value tied to multiple sessions within a single process
    case process

    /// value tied to the Embrace datastore. Will associate with all sessions until explicitly removed
    case permanent
}

public struct ResourceRecord: Codable {
    public let resourceType: ResourceType
    public let resourceTypeId: String
    public let key: String
    public var value: AttributeValue
    public let collectedAt: Date

    /// Main initializer for the ResourceRecord
    ///
    /// - Note: Its recommended to use any of the ResourceType specific initializers listed below
    init(
        key: String,
        value: AttributeValue,
        resourceType: ResourceType,
        resourceTypeId: String,
        collectedAt: Date = Date()
    ) {
        self.key = key
        self.value = value
        self.resourceType = resourceType
        self.resourceTypeId = resourceTypeId
        self.collectedAt = collectedAt
    }

    /// Initialize a session resource
    /// A session resource uses a ``EmbraceCommon.SessionIdentifier`` as the resourceTypeId
    /// - Parameters:
    ///     - key: The unique identifier of the session resource
    ///     - value: The value of the resource, encoded as a String
    ///     - sessionId: The session identifier of the session the resource is associated with
    ///     - collectedAt: The date the resource item was collected
    public init(key: String, value: String, sessionId: SessionIdentifier, collectedAt: Date = Date()) {
        self.init(
            key: key,
            value: .string(value),
            resourceType: .session,
            resourceTypeId: sessionId.toString,
            collectedAt: collectedAt
        )
    }

    /// Initialize a process resource
    /// A process resource uses a ``EmbraceCommon.ProcessIdentifier`` as the resourceTypeId
    /// - Parameters:
    ///     - key: The unique identifier of the process resource
    ///     - value: The value of the resource, encoded as a String
    ///     - processIdentifier: The process identifier of the process the resource is associated with
    ///     - collectedAt: The date the resource item was collected
    public init(key: String, value: String, processIdentifier: ProcessIdentifier, collectedAt: Date = Date()) {
        self.init(
            key: key,
            value: .string(value),
            resourceType: .process,
            resourceTypeId: processIdentifier.hex,
            collectedAt: collectedAt
        )
    }

    /// Initialize a permanent resource
    /// A permanent resource does not need a resourceTypeId as it is implicit
    /// - Parameters:
    ///     - key: The unique identifier of the permanent resource
    ///     - value: The value of the resource, encoded as a String
    ///     - collectedAt: The date the resource item was collected
    public init(key: String, value: String, collectedAt: Date = Date()) {
        self.init(
            key: key,
            value: .string(value),
            resourceType: .permanent,
            resourceTypeId: "",
            collectedAt: collectedAt
        )
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
