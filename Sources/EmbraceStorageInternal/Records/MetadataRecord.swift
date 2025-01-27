//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal
import CoreData
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

public class MetadataRecord: NSManagedObject {
    @NSManaged public var key: String
    @NSManaged public var value: String
    @NSManaged public var typeRaw: String // MetadataRecordType
    @NSManaged public var lifespanRaw: String // MetadataRecordLifespan
    @NSManaged public var lifespanId: String
    @NSManaged public var collectedAt: Date

    public var type: MetadataRecordType? {
        return MetadataRecordType(rawValue: typeRaw)
    }

    public var lifespan: MetadataRecordLifespan? {
        return MetadataRecordLifespan(rawValue: lifespanRaw)
    }

    public static func create(
        context: NSManagedObjectContext,
        key: String,
        value: String,
        type: MetadataRecordType,
        lifespan: MetadataRecordLifespan,
        lifespanId: String,
        collectedAt: Date = Date()
    ) -> MetadataRecord {
        let record = MetadataRecord(context: context)
        record.key = key
        record.value = value
        record.typeRaw = type.rawValue
        record.lifespanRaw = lifespan.rawValue
        record.lifespanId = lifespanId
        record.collectedAt = collectedAt

        return record
    }

    static func createFetchRequest() -> NSFetchRequest<MetadataRecord> {
        return NSFetchRequest<MetadataRecord>(entityName: entityName)
    }
}

extension MetadataRecord: EmbraceStorageRecord {
    public static var entityName = "MetadataRecord"

    static public var entityDescription: NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = entityName
        entity.managedObjectClassName = NSStringFromClass(MetadataRecord.self)

        let keyAttribute = NSAttributeDescription()
        keyAttribute.name = "key"
        keyAttribute.attributeType = .stringAttributeType

        let valueAttribute = NSAttributeDescription()
        valueAttribute.name = "value"
        valueAttribute.attributeType = .stringAttributeType

        let typeAttribute = NSAttributeDescription()
        typeAttribute.name = "typeRaw"
        typeAttribute.attributeType = .stringAttributeType

        let lifespanAttribute = NSAttributeDescription()
        lifespanAttribute.name = "lifespanRaw"
        lifespanAttribute.attributeType = .stringAttributeType

        let lifespanIdAttribute = NSAttributeDescription()
        lifespanIdAttribute.name = "lifespanId"
        lifespanIdAttribute.attributeType = .stringAttributeType

        let collectedAtAttribute = NSAttributeDescription()
        collectedAtAttribute.name = "collectedAt"
        collectedAtAttribute.attributeType = .dateAttributeType

        entity.properties = [
            keyAttribute,
            valueAttribute,
            typeAttribute,
            lifespanAttribute,
            lifespanIdAttribute,
            collectedAtAttribute
        ]

        return entity
    }
}

extension MetadataRecord {
    public static let lifespanIdForPermanent = ""
}
