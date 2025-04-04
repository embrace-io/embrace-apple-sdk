//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal
import OpenTelemetryApi
import CoreData

@objc(LogRecord)
public class LogRecord: NSManagedObject {
    @NSManaged public var idRaw: String // LogIdentifier
    @NSManaged public var processIdRaw: String // ProcessIdentifier
    @NSManaged public var severityRaw: Int // LogSeverity
    @NSManaged public var body: String
    @NSManaged public var timestamp: Date
    @NSManaged public var attributes: Set<LogAttributeRecord>

    class func create(
        context: NSManagedObjectContext,
        id: LogIdentifier,
        processId: ProcessIdentifier,
        severity: LogSeverity,
        body: String,
        timestamp: Date = Date(),
        attributes: [String: AttributeValue]
    ) -> EmbraceLog? {
        var result: EmbraceLog?

        context.performAndWait {
            guard let description = NSEntityDescription.entity(forEntityName: Self.entityName, in: context) else {
                return
            }

            let record = LogRecord(entity: description, insertInto: context)
            record.idRaw = id.toString
            record.processIdRaw = processId.hex
            record.severityRaw = severity.rawValue
            record.body = body
            record.timestamp = timestamp
            record.attributes = Set()

            for (key, value) in attributes {
                if let attribute = LogAttributeRecord.create(
                    context: context,
                    key: key,
                    value: value,
                    log: record
                ) {
                    record.attributes.insert(attribute)
                }
            }

            result = record.toImmutable()
        }

        return result
    }

    static func createFetchRequest() -> NSFetchRequest<LogRecord> {
        return NSFetchRequest<LogRecord>(entityName: entityName)
    }

    func toImmutable() -> EmbraceLog {
        let attributes = attributes.map { $0.toImmutable() }

        return ImmutableLogRecord(
            idRaw: idRaw,
            processIdRaw: processIdRaw,
            severityRaw: severityRaw,
            body: body,
            timestamp: timestamp,
            attributes: attributes
        )
    }
}

extension LogRecord: EmbraceStorageRecord {
    public static var entityName = "LogRecord"

    static public var entityDescriptions: [NSEntityDescription] {
        let entity = NSEntityDescription()
        entity.name = entityName
        entity.managedObjectClassName = NSStringFromClass(LogRecord.self)

        let child = NSEntityDescription()
        child.name = LogAttributeRecord.entityName
        child.managedObjectClassName = NSStringFromClass(LogAttributeRecord.self)

        // parent
        let idAttribute = NSAttributeDescription()
        idAttribute.name = "idRaw"
        idAttribute.attributeType = .stringAttributeType

        let processIdAttribute = NSAttributeDescription()
        processIdAttribute.name = "processIdRaw"
        processIdAttribute.attributeType = .stringAttributeType

        let severityAttribute = NSAttributeDescription()
        severityAttribute.name = "severityRaw"
        severityAttribute.attributeType = .integer64AttributeType

        let bodyAttribute = NSAttributeDescription()
        bodyAttribute.name = "body"
        bodyAttribute.attributeType = .stringAttributeType

        let timestampAttribute = NSAttributeDescription()
        timestampAttribute.name = "timestamp"
        timestampAttribute.attributeType = .dateAttributeType

        // child
        let keyAttribute = NSAttributeDescription()
        keyAttribute.name = "key"
        keyAttribute.attributeType = .stringAttributeType

        let valueAttribute = NSAttributeDescription()
        valueAttribute.name = "valueRaw"
        valueAttribute.attributeType = .stringAttributeType

        let typeAttribute = NSAttributeDescription()
        typeAttribute.name = "typeRaw"
        typeAttribute.attributeType = .integer64AttributeType

        // relationships
        let parentRelationship = NSRelationshipDescription()
        let childRelationship = NSRelationshipDescription()

        parentRelationship.name = "attributes"
        parentRelationship.deleteRule = .cascadeDeleteRule
        parentRelationship.destinationEntity = child
        parentRelationship.inverseRelationship = childRelationship

        childRelationship.name = "log"
        childRelationship.minCount = 1
        childRelationship.maxCount = 1
        childRelationship.destinationEntity = entity
        childRelationship.inverseRelationship = parentRelationship

        // set properties
        entity.properties = [
            idAttribute,
            processIdAttribute,
            severityAttribute,
            bodyAttribute,
            timestampAttribute,
            parentRelationship
        ]

        child.properties = [
            keyAttribute,
            valueAttribute,
            typeAttribute,
            childRelationship
        ]

        return [entity, child]
    }
}

struct ImmutableLogRecord: EmbraceLog {
    let idRaw: String
    let processIdRaw: String
    let severityRaw: Int
    let body: String
    let timestamp: Date
    let attributes: [EmbraceLogAttribute]

    func allAttributes() -> [any EmbraceCommonInternal.EmbraceLogAttribute] {
        return attributes
    }

    func attribute(forKey key: String) -> (any EmbraceCommonInternal.EmbraceLogAttribute)? {
        return attributes.first(where: { $0.key == key })
    }
}
