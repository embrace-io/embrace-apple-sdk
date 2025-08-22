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
    @NSManaged public var attributes: String

    class func create(context: NSManagedObjectContext, log: EmbraceLog) {
        context.performAndWait {
            guard let description = NSEntityDescription.entity(forEntityName: Self.entityName, in: context) else {
                return
            }

            let record = LogRecord(entity: description, insertInto: context)
            record.id = log.id
            record.sessionIdRaw = log.sessionId?.stringValue
            record.processIdRaw = log.processId.stringValue
            record.severityRaw = log.severity.rawValue
            record.body = log.body
            record.timestamp = log.timestamp
            record.attributes = log.attributes.keyValueEncoded()
        }
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
            sessionId: sessionId,
            processId: EmbraceIdentifier(stringValue: processIdRaw),
            severity: EmbraceLogSeverity(rawValue: severityRaw) ?? .debug,
            timestamp: timestamp,
            body: body,
            attributes: attributes ?? .keyValueDecode(self.attributes)
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
            bodyAttribute,
            timestampAttribute,
            attributesAttribute
        ]

        return entity
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
}
