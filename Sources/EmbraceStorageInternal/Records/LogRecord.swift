//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import CoreData
import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

@objc(LogRecord)
public class LogRecord: NSManagedObject {
    @NSManaged public var id: String
    @NSManaged public var sessionIdRaw: String?
    @NSManaged public var processIdRaw: String
    @NSManaged public var severityRaw: Int
    @NSManaged public var body: String
    @NSManaged public var timestamp: Date
    @NSManaged public var attributes: Set<LogAttributeRecord>

    class func create(
        context: NSManagedObjectContext,
        id: String,
        sessionId: EmbraceIdentifier?,
        processId: EmbraceIdentifier,
        severity: EmbraceLogSeverity,
        body: String,
        timestamp: Date = Date(),
        attributes: [String: String]
    ) -> EmbraceLog? {
        var result: EmbraceLog?

        context.performAndWait {
            guard let description = NSEntityDescription.entity(forEntityName: Self.entityName, in: context) else {
                return
            }

            let record = LogRecord(entity: description, insertInto: context)
            record.id = id
            record.sessionIdRaw = sessionId?.stringValue
            record.processIdRaw = processId.stringValue
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

        var sessionId: EmbraceIdentifier?
        if let sessionIdRaw {
            sessionId = EmbraceIdentifier(stringValue: sessionIdRaw)
        }

        let finalAttributes = attributes.reduce(into: [String: String]()) {
            $0[$1.key] = $1.value
        }

        return ImmutableLogRecord(
            id: id,
            sessionId: sessionId,
            processId: EmbraceIdentifier(stringValue: processIdRaw),
            severity: EmbraceLogSeverity(rawValue: severityRaw) ?? .debug,
            timestamp: timestamp,
            body: body,
            attributes: finalAttributes
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
        idAttribute.name = "id"
        idAttribute.attributeType = .stringAttributeType

        let sessionIdAttribute = NSAttributeDescription()
        sessionIdAttribute.name = "sessionIdRaw"
        sessionIdAttribute.attributeType = .stringAttributeType
        sessionIdAttribute.isOptional = true

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
        timestampAttribute.defaultValue = Date()

        // child
        let keyAttribute = NSAttributeDescription()
        keyAttribute.name = "key"
        keyAttribute.attributeType = .stringAttributeType

        let valueAttribute = NSAttributeDescription()
        valueAttribute.name = "value"
        valueAttribute.attributeType = .stringAttributeType

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
            sessionIdAttribute,
            processIdAttribute,
            severityAttribute,
            bodyAttribute,
            timestampAttribute,
            parentRelationship
        ]

        child.properties = [
            keyAttribute,
            valueAttribute,
            childRelationship
        ]

        return [entity, child]
    }
}

struct ImmutableLogRecord: EmbraceLog {
    var id: String
    var sessionId: EmbraceIdentifier?
    var processId: EmbraceIdentifier
    var severity: EmbraceLogSeverity
    let timestamp: Date
    let body: String
    let attributes: [String: String]

    func setAttribute(key: String, value: String?) {
        // no op
    }
}
