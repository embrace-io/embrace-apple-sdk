//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceCommonInternal
#endif
import OpenTelemetryApi
import CoreData

@objc(MetadataRecord)
public class MetadataRecord: NSManagedObject {
    @NSManaged public var key: String
    @NSManaged public var value: String
    @NSManaged public var typeRaw: String // MetadataRecordType
    @NSManaged public var lifespanRaw: String // MetadataRecordLifespan
    @NSManaged public var lifespanId: String
    @NSManaged public var collectedAt: Date

    class func create(
        context: NSManagedObjectContext,
        key: String,
        value: String,
        type: MetadataRecordType,
        lifespan: MetadataRecordLifespan,
        lifespanId: String,
        collectedAt: Date = Date()
    ) -> EmbraceMetadata? {
        var result: EmbraceMetadata?

        context.performAndWait {
            guard let description = NSEntityDescription.entity(forEntityName: Self.entityName, in: context) else {
                return
            }

            let record = MetadataRecord(entity: description, insertInto: context)
            record.key = key
            record.value = value
            record.typeRaw = type.rawValue
            record.lifespanRaw = lifespan.rawValue
            record.lifespanId = lifespanId
            record.collectedAt = collectedAt

            result = record.toImmutable()
        }

        return result
    }

    static func createFetchRequest() -> NSFetchRequest<MetadataRecord> {
        return NSFetchRequest<MetadataRecord>(entityName: entityName)
    }

    func toImmutable() -> EmbraceMetadata {
        return ImmutableMetadataRecord(
            key: key,
            value: value,
            typeRaw: typeRaw,
            lifespanRaw: lifespanRaw,
            lifespanId: lifespanId,
            collectedAt: collectedAt
        )
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

struct ImmutableMetadataRecord: EmbraceMetadata {
    let key: String
    let value: String
    let typeRaw: String
    let lifespanRaw: String
    let lifespanId: String
    let collectedAt: Date
}
