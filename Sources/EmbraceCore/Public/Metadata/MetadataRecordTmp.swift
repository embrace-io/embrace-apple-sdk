//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import CoreData
import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceStorageInternal
#endif

@objc(MetadataRecordTmp)
public class MetadataRecordTmp: NSManagedObject {
    @NSManaged var key: String
    @NSManaged var value: String
    @NSManaged var type: String
    @NSManaged var lifespan: String
    @NSManaged var lifespanId: String
    @NSManaged var collectedAt: Date

    class func create(
        context: NSManagedObjectContext,
        key: String,
        value: String,
        type: String,
        lifespan: String,
        lifespanId: String,
        collectedAt: Date = Date()
    ) -> MetadataRecordTmp? {
        var record: MetadataRecordTmp?

        context.performAndWait {
            guard let description = NSEntityDescription.entity(forEntityName: Self.entityName, in: context) else {
                return
            }

            record = MetadataRecordTmp(entity: description, insertInto: context)
            record?.key = key
            record?.value = value
            record?.type = type
            record?.lifespan = lifespan
            record?.lifespanId = lifespanId
            record?.collectedAt = collectedAt
        }

        return record
    }
}

extension MetadataRecordTmp {
    static let entityName = "MetadataRecordTmp"

    static var entityDescription: NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = entityName
        entity.managedObjectClassName = NSStringFromClass(MetadataRecordTmp.self)

        let keyAttribute = NSAttributeDescription()
        keyAttribute.name = "key"
        keyAttribute.attributeType = .stringAttributeType

        let valueAttribute = NSAttributeDescription()
        valueAttribute.name = "value"
        valueAttribute.attributeType = .stringAttributeType

        let typeAttribute = NSAttributeDescription()
        typeAttribute.name = "type"
        typeAttribute.attributeType = .stringAttributeType

        let lifespanAttribute = NSAttributeDescription()
        lifespanAttribute.name = "lifespan"
        lifespanAttribute.attributeType = .stringAttributeType

        let lifespanIdAttribute = NSAttributeDescription()
        lifespanIdAttribute.name = "lifespanId"
        lifespanIdAttribute.attributeType = .stringAttributeType

        let dateAttribute = NSAttributeDescription()
        dateAttribute.name = "collectedAt"
        dateAttribute.attributeType = .dateAttributeType

        entity.properties = [
            keyAttribute,
            valueAttribute,
            typeAttribute,
            lifespanAttribute,
            lifespanIdAttribute,
            dateAttribute,
        ]

        return entity
    }
}
