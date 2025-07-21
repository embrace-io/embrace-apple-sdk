//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import CoreData
import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

/// Represents a span in the storage
@objc(SpanRecord)
public class SpanRecord: NSManagedObject {
    @NSManaged public var id: String
    @NSManaged public var name: String
    @NSManaged public var traceId: String
    @NSManaged public var typeRaw: String  // SpanType
    @NSManaged public var data: Data
    @NSManaged public var startTime: Date
    @NSManaged public var endTime: Date?
    @NSManaged public var processIdRaw: String  // ProcessIdentifier
    @NSManaged public var sessionIdRaw: String?  // SessionIdentifier

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
    ) -> EmbraceSpan? {
        var result: EmbraceSpan?

        context.performAndWait {
            guard let description = NSEntityDescription.entity(forEntityName: Self.entityName, in: context) else {
                return
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

            result = record.toImmutable()
        }

        return result
    }

    static func createFetchRequest() -> NSFetchRequest<SpanRecord> {
        return NSFetchRequest<SpanRecord>(entityName: entityName)
    }

    func toImmutable() -> EmbraceSpan {
        return ImmutableSpanRecord(
            id: id,
            name: name,
            traceId: traceId,
            typeRaw: typeRaw,
            data: data,
            startTime: startTime,
            endTime: endTime,
            processIdRaw: processIdRaw
        )
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
        startTimeAttribute.defaultValue = Date()

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
            processIdAttribute,
            sessionIdAttribute,
        ]

        return entity
    }
}

struct ImmutableSpanRecord: EmbraceSpan {
    let id: String
    let name: String
    let traceId: String
    let typeRaw: String
    let data: Data
    let startTime: Date
    let endTime: Date?
    let processIdRaw: String
}
