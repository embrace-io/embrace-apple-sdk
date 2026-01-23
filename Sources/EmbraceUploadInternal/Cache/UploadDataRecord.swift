//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import CoreData
import Foundation

/// Represents a cached upload data in the storage
@objc(UploadDataRecord)
public class UploadDataRecord: NSManagedObject {
    @NSManaged var id: String
    @NSManaged var type: Int
    @NSManaged var data: Data
    @NSManaged var payloadTypes: String?
    @NSManaged var attemptCount: Int
    @NSManaged var date: Date

    class func create(
        context: NSManagedObjectContext,
        id: String,
        type: Int,
        data: Data,
        payloadTypes: String?,
        attemptCount: Int,
        date: Date
    ) -> UploadDataRecord? {
        var record: UploadDataRecord?

        context.performAndWait {
            guard let description = NSEntityDescription.entity(forEntityName: Self.entityName, in: context) else {
                return
            }

            record = UploadDataRecord(entity: description, insertInto: context)
            record?.id = id
            record?.type = type
            record?.data = data
            record?.payloadTypes = payloadTypes
            record?.attemptCount = attemptCount
            record?.date = date
        }

        return record
    }

    func toImmutable() -> ImmutableUploadDataRecord {
        return ImmutableUploadDataRecord(
            id: id,
            type: type,
            data: data,
            payloadTypes: payloadTypes,
            attemptCount: attemptCount,
            date: date
        )
    }
}

extension UploadDataRecord {
    static let entityName = "UploadData"

    static var entityDescription: NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = entityName
        entity.managedObjectClassName = NSStringFromClass(UploadDataRecord.self)

        let idAttribute = NSAttributeDescription()
        idAttribute.name = "id"
        idAttribute.attributeType = .stringAttributeType

        let typeAttribute = NSAttributeDescription()
        typeAttribute.name = "type"
        #if arch(arm64_32)
            typeAttribute.attributeType = .integer32AttributeType
        #else
            typeAttribute.attributeType = .integer64AttributeType
        #endif

        let dataAttribute = NSAttributeDescription()
        dataAttribute.name = "data"
        dataAttribute.attributeType = .binaryDataAttributeType

        let payloadTypesAttribute = NSAttributeDescription()
        payloadTypesAttribute.name = "payloadTypes"
        payloadTypesAttribute.attributeType = .stringAttributeType
        payloadTypesAttribute.isOptional = true
        payloadTypesAttribute.defaultValue = nil

        let attemptCountAttribute = NSAttributeDescription()
        attemptCountAttribute.name = "attemptCount"
        #if arch(arm64_32)
            attemptCountAttribute.attributeType = .integer32AttributeType
        #else
            attemptCountAttribute.attributeType = .integer64AttributeType
        #endif

        let dateAttribute = NSAttributeDescription()
        dateAttribute.name = "date"
        dateAttribute.attributeType = .dateAttributeType

        entity.properties = [
            idAttribute,
            typeAttribute,
            dataAttribute,
            payloadTypesAttribute,
            attemptCountAttribute,
            dateAttribute
        ]

        return entity
    }
}

struct ImmutableUploadDataRecord {
    let id: String
    let type: Int
    let data: Data
    let payloadTypes: String?
    let attemptCount: Int
    let date: Date
}
