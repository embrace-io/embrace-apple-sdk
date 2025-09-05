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
    @NSManaged public var severityRaw: Int
    @NSManaged public var typeRaw: String
    @NSManaged public var body: String
    @NSManaged public var timestamp: Date
    @NSManaged public var attributes: String
    @NSManaged public var sessionIdRaw: String?
    @NSManaged public var processIdRaw: String

    class func create(
        context: NSManagedObjectContext,
        id: String,
        sessionId: EmbraceIdentifier?,
        processId: EmbraceIdentifier,
        severity: EmbraceLogSeverity,
        type: EmbraceType,
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
            record.typeRaw = type.rawValue
            record.body = body
            record.timestamp = timestamp
            record.attributes = attributes.keyValueEncoded()

            result = record.toImmutable(attributes: attributes)
        }

        return result
    }

    static func createFetchRequest() -> NSFetchRequest<LogRecord> {
        return NSFetchRequest<LogRecord>(entityName: entityName)
    }

    func toImmutable(attributes: [String: String]? = nil) -> EmbraceLog {

        var sessionId: EmbraceIdentifier?
        if let sessionIdRaw {
            sessionId = EmbraceIdentifier(stringValue: sessionIdRaw)
        }

        return ImmutableLogRecord(
            id: id,
            severity: EmbraceLogSeverity(rawValue: severityRaw) ?? .debug,
            type: EmbraceType(rawValue: typeRaw) ?? .message,
            timestamp: timestamp,
            body: body,
            attributes: attributes ?? .keyValueDecode(self.attributes),
            sessionId: sessionId,
            processId: EmbraceIdentifier(stringValue: processIdRaw),

        )
    }
}

extension LogRecord: EmbraceStorageRecord {
    public static var entityName = "LogRecord"

    static public var entityDescription: NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = entityName
        entity.managedObjectClassName = NSStringFromClass(LogRecord.self)

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

        let typeAttribute = NSAttributeDescription()
        typeAttribute.name = "typeRaw"
        typeAttribute.attributeType = .stringAttributeType

        let bodyAttribute = NSAttributeDescription()
        bodyAttribute.name = "body"
        bodyAttribute.attributeType = .stringAttributeType

        let timestampAttribute = NSAttributeDescription()
        timestampAttribute.name = "timestamp"
        timestampAttribute.attributeType = .dateAttributeType
        timestampAttribute.defaultValue = Date()

        let attributesAttribute = NSAttributeDescription()
        attributesAttribute.name = "attributes"
        attributesAttribute.attributeType = .stringAttributeType

        // set properties
        entity.properties = [
            idAttribute,
            sessionIdAttribute,
            processIdAttribute,
            severityAttribute,
            typeAttribute,
            bodyAttribute,
            timestampAttribute,
            attributesAttribute
        ]

        return entity
    }
}

class ImmutableLogRecord: EmbraceLog {
    let id: String
    let severity: EmbraceLogSeverity
    let type: EmbraceType
    let timestamp: Date
    let body: String
    let attributes: [String: String]
    let sessionId: EmbraceIdentifier?
    let processId: EmbraceIdentifier

    init(
        id: String,
        severity: EmbraceLogSeverity,
        type: EmbraceType,
        timestamp: Date,
        body: String,
        attributes: [String: String],
        sessionId: EmbraceIdentifier? = nil,
        processId: EmbraceIdentifier
    ) {
        self.id = id
        self.severity = severity
        self.type = type
        self.timestamp = timestamp
        self.body = body
        self.attributes = attributes
        self.sessionId = sessionId
        self.processId = processId
    }
}
