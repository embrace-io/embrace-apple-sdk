//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import CoreData

/// Represents a cached upload data in the storage
@objc(UploadDataRecord)
public class UploadDataRecord: NSManagedObject {
    @NSManaged var id: String
    @NSManaged var type: Int
    @NSManaged var data: Data
    @NSManaged var attemptCount: Int
    @NSManaged var date: Date

    class func create(
        context: NSManagedObjectContext,
        id: String,
        type: Int,
        data: Data,
        attemptCount:
        Int,
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
            record?.attemptCount = attemptCount
            record?.date = date
        }

        return record
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
        typeAttribute.attributeType = .integer64AttributeType

        let dataAttribute = NSAttributeDescription()
        dataAttribute.name = "data"
        dataAttribute.attributeType = .binaryDataAttributeType

        let attemptCountAttribute = NSAttributeDescription()
        attemptCountAttribute.name = "attemptCount"
        attemptCountAttribute.attributeType = .integer64AttributeType

        let dateAttribute = NSAttributeDescription()
        dateAttribute.name = "date"
        dateAttribute.attributeType = .dateAttributeType

        entity.properties = [idAttribute, typeAttribute, dataAttribute, attemptCountAttribute, dateAttribute]
        return entity
    }
}
