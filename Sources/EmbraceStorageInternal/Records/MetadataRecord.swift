//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal
import GRDB
import OpenTelemetryApi

public enum MetadataRecordType: String, Codable {
    /// Resource that is attached to session and logs data
    case resource

    /// Embrace-generated resource that is deemed required and cannot be removed by the user of the SDK
    case requiredResource

    /// Custom property attached to session and logs data and that can be manipulated by the user of the SDK
    case customProperty

    /// Persona tag attached to session and logs data and that can be manipulated by the user of the SDK
    case personaTag
}

public enum MetadataRecordLifespan: String, Codable {
    /// Value tied to a specific session
    case session

    /// Value tied to multiple sessions within a single process
    case process

    /// Value tied to all sessions until explicitly removed
    case permanent
}

public struct MetadataRecord: Codable {
    public let key: String
    public var value: AttributeValue
    public let type: MetadataRecordType
    public let lifespan: MetadataRecordLifespan
    public let lifespanId: String
    public let collectedAt: Date

    /// Main initializer for the MetadataRecord
    public init(
        key: String,
        value: AttributeValue,
        type: MetadataRecordType,
        lifespan: MetadataRecordLifespan,
        lifespanId: String,
        collectedAt: Date = Date()
    ) {
        self.key = key
        self.value = value
        self.type = type
        self.lifespan = lifespan
        self.lifespanId = lifespanId
        self.collectedAt = collectedAt
    }
}

extension MetadataRecord {
    struct Schema {
        static var key: Column { Column("key") }
        static var value: Column { Column("value") }
        static var type: Column { Column("type") }
        static var lifespan: Column { Column("lifespan") }
        static var lifespanId: Column { Column("lifespan_id") }
        static var collectedAt: Column { Column("collected_at") }
    }
}

extension MetadataRecord: FetchableRecord, PersistableRecord, MutablePersistableRecord {
    public static let databaseTableName: String = "metadata"

    public static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase
    public static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    public static let persistenceConflictPolicy = PersistenceConflictPolicy(insert: .replace, update: .replace)
}

extension MetadataRecord: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.key == rhs.key
    }
}
