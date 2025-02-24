//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal
import CoreData

/// Represents a span in the storage
public class SpanRecord: NSManagedObject, EmbraceSpan {
    @NSManaged public var id: String
    @NSManaged public var name: String
    @NSManaged public var traceId: String
    @NSManaged public var typeRaw: String // SpanType
    @NSManaged public var data: Data
    @NSManaged public var startTime: Date
    @NSManaged public var endTime: Date?
    @NSManaged public var processIdRaw: String // ProcessIdentifier
    @NSManaged public var sessionIdRaw: String? // SessionIdentifier

    class func create(
        context: NSManagedObjectContext,
        id: String,
        name: String,
        traceId: String,
        type: SpanType,
        data: Data,
        startTime: Date,
        endTime: Date? = nil,
        processId: ProcessIdentifier,
        sessionId: SessionIdentifier? = nil
    ) -> SpanRecord? {
        guard let description = NSEntityDescription.entity(forEntityName: Self.entityName, in: context) else {
            return nil
        }

        let record = SpanRecord(entity: description, insertInto: context)
        record.id = id
        record.name = name
        record.traceId = traceId
        record.typeRaw = type.rawValue
        record.data = data
        record.startTime = startTime
        record.endTime = endTime
        record.processIdRaw = processId.hex
        record.sessionIdRaw = sessionId?.toString

        return record
    }

    static func createFetchRequest() -> NSFetchRequest<SpanRecord> {
        return NSFetchRequest<SpanRecord>(entityName: entityName)
    }
}

extension SpanRecord: EmbraceStorageRecord {
    public static var entityName = "SpanRecord"

    static public var entityDescription: NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = entityName
        entity.managedObjectClassName = NSStringFromClass(SpanRecord.self)

        let idAttribute = NSAttributeDescription()
        idAttribute.name = "id"
        idAttribute.attributeType = .stringAttributeType

        let nameAttribute = NSAttributeDescription()
        nameAttribute.name = "name"
        nameAttribute.attributeType = .stringAttributeType

        let traceIdAttribute = NSAttributeDescription()
        traceIdAttribute.name = "traceId"
        traceIdAttribute.attributeType = .stringAttributeType

        let typeAttribute = NSAttributeDescription()
        typeAttribute.name = "typeRaw"
        typeAttribute.attributeType = .stringAttributeType

        let dataAttribute = NSAttributeDescription()
        dataAttribute.name = "data"
        dataAttribute.attributeType = .binaryDataAttributeType

        let startTimeAttribute = NSAttributeDescription()
        startTimeAttribute.name = "startTime"
        startTimeAttribute.attributeType = .dateAttributeType

        let endTimeAttribute = NSAttributeDescription()
        endTimeAttribute.name = "endTime"
        endTimeAttribute.attributeType = .dateAttributeType
        endTimeAttribute.isOptional = true

        let processIdAttribute = NSAttributeDescription()
        processIdAttribute.name = "processIdRaw"
        processIdAttribute.attributeType = .stringAttributeType

        let sessionIdAttribute = NSAttributeDescription()
        sessionIdAttribute.name = "sessionIdRaw"
        sessionIdAttribute.attributeType = .stringAttributeType
        sessionIdAttribute.isOptional = true

        entity.properties = [
            idAttribute,
            nameAttribute,
            traceIdAttribute,
            typeAttribute,
            dataAttribute,
            startTimeAttribute,
            endTimeAttribute,
            processIdAttribute
        ]

        return entity
    }
}
