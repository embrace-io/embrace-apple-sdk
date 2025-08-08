//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import CoreData
import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

/// Represents a span in the storage
@objc(SpanRecord)
public class SpanRecord: NSManagedObject {
    @NSManaged public var id: String
    @NSManaged public var traceId: String
    @NSManaged public var parentSpanId: String?
    @NSManaged public var name: String
    @NSManaged public var typeRaw: String
    @NSManaged public var statusRaw: Int
    @NSManaged public var startTime: Date
    @NSManaged public var endTime: Date?
    @NSManaged public var sessionIdRaw: String?
    @NSManaged public var processIdRaw: String
    @NSManaged public var events: Set<SpanEventRecord>
    @NSManaged public var links: Set<SpanLinkRecord>
    @NSManaged public var attributes: Set<SpanAttributeRecord>

    class func create(
        context: NSManagedObjectContext,
        id: String,
        traceId: String,
        parentSpanId: String?,
        name: String,
        type: EmbraceType,
        status: EmbraceSpanStatus,
        startTime: Date,
        endTime: Date? = nil,
        sessionId: EmbraceIdentifier? = nil,
        processId: EmbraceIdentifier,
        events: [EmbraceSpanEvent] = [],
        links: [EmbraceSpanLink] = [],
        attributes: [String: String]
    ) -> EmbraceSpan? {
        var result: EmbraceSpan?

        context.performAndWait {
            guard let description = NSEntityDescription.entity(forEntityName: Self.entityName, in: context) else {
                return
            }

            let record = SpanRecord(entity: description, insertInto: context)
            record.id = id
            record.traceId = traceId
            record.parentSpanId = parentSpanId
            record.name = name
            record.typeRaw = type.rawValue
            record.statusRaw = status.rawValue
            record.startTime = startTime
            record.endTime = endTime
            record.sessionIdRaw = sessionId?.stringValue
            record.processIdRaw = processId.stringValue

            // events
            for event in events {
                if let event = SpanEventRecord.create(
                    context: context,
                    name: event.name,
                    timestamp: event.timestamp,
                    attributes: event.attributes,
                    span: record
                ) {
                    record.events.insert(event)
                }
            }

            // links
            for link in links {
                if let link = SpanLinkRecord.create(
                    context: context,
                    spanId: link.spanId,
                    traceId: link.traceId,
                    attributes: link.attributes,
                    span: record
                ) {
                    record.links.insert(link)
                }
            }

            // attributes
            for (key, value) in attributes {
                if let attribute = SpanAttributeRecord.create(
                    context: context,
                    key: key,
                    value: value,
                    span: record
                ) {
                    record.attributes.insert(attribute)
                }
            }

            result = record.toImmutable()
        }

        return result
    }

    static func createFetchRequest() -> NSFetchRequest<SpanRecord> {
        return NSFetchRequest<SpanRecord>(entityName: entityName)
    }

    func toImmutable() -> EmbraceSpan {

        var sessionId: EmbraceIdentifier?
        if let sessionIdRaw {
            sessionId = EmbraceIdentifier(stringValue: sessionIdRaw)
        }

        let finalEvents = events.map {
            $0.toImmutable()
        }

        let finalLinks = links.map {
            $0.toImmutable()
        }

        let finalAttributes = attributes.reduce(into: [String: String]()) {
            $0[$1.key] = $1.value
        }

        return ImmutableSpanRecord(
            id: id,
            traceId: traceId,
            parentSpanId: parentSpanId,
            name: name,
            type: EmbraceType(rawValue: typeRaw) ?? .performance,
            status: EmbraceSpanStatus(rawValue: statusRaw) ?? .unset,
            startTime: startTime,
            endTime: endTime,
            sessionId: sessionId,
            processId: EmbraceIdentifier(stringValue: processIdRaw),
            events: finalEvents,
            links: finalLinks,
            attributes: finalAttributes
        )
    }
}

extension SpanRecord: EmbraceStorageRecord {
    public static var entityName = "SpanRecord"

    static public var entityDescriptions: [NSEntityDescription] {
        let entity = NSEntityDescription()
        entity.name = entityName
        entity.managedObjectClassName = NSStringFromClass(SpanRecord.self)

        let attributes = NSEntityDescription()
        attributes.name = SpanAttributeRecord.entityName
        attributes.managedObjectClassName = NSStringFromClass(SpanAttributeRecord.self)

        let events = NSEntityDescription()
        events.name = SpanEventRecord.entityName
        events.managedObjectClassName = NSStringFromClass(SpanEventRecord.self)

        let eventAttributes = NSEntityDescription()
        eventAttributes.name = SpanEventAttributeRecord.entityName
        eventAttributes.managedObjectClassName = NSStringFromClass(SpanEventAttributeRecord.self)

        let links = NSEntityDescription()
        links.name = SpanLinkRecord.entityName
        links.managedObjectClassName = NSStringFromClass(SpanLinkRecord.self)

        let linkAttributes = NSEntityDescription()
        links.name = SpanLinkAttributeRecord.entityName
        links.managedObjectClassName = NSStringFromClass(SpanLinkAttributeRecord.self)

        // span
        let idAttribute = NSAttributeDescription()
        idAttribute.name = "id"
        idAttribute.attributeType = .stringAttributeType

        let traceIdAttribute = NSAttributeDescription()
        traceIdAttribute.name = "traceId"
        traceIdAttribute.attributeType = .stringAttributeType

        let parentSpanIdAttribute = NSAttributeDescription()
        parentSpanIdAttribute.name = "parentSpanId"
        parentSpanIdAttribute.attributeType = .stringAttributeType
        parentSpanIdAttribute.isOptional = true

        let sessionIdAttribute = NSAttributeDescription()
        sessionIdAttribute.name = "sessionIdRaw"
        sessionIdAttribute.attributeType = .stringAttributeType
        sessionIdAttribute.isOptional = true

        let processIdAttribute = NSAttributeDescription()
        processIdAttribute.name = "processIdRaw"
        processIdAttribute.attributeType = .stringAttributeType

        let nameAttribute = NSAttributeDescription()
        nameAttribute.name = "name"
        nameAttribute.attributeType = .stringAttributeType

        let typeAttribute = NSAttributeDescription()
        typeAttribute.name = "typeRaw"
        typeAttribute.attributeType = .stringAttributeType

        let statusAttribute = NSAttributeDescription()
        statusAttribute.name = "statusRaw"
        statusAttribute.attributeType = .integer32AttributeType

        let startTimeAttribute = NSAttributeDescription()
        startTimeAttribute.name = "startTime"
        startTimeAttribute.attributeType = .dateAttributeType
        startTimeAttribute.defaultValue = Date()

        let endTimeAttribute = NSAttributeDescription()
        endTimeAttribute.name = "endTime"
        endTimeAttribute.attributeType = .dateAttributeType
        endTimeAttribute.isOptional = true

        // span attributes
        let spanAttributeKeyAttribute = NSAttributeDescription()
        spanAttributeKeyAttribute.name = "key"
        spanAttributeKeyAttribute.attributeType = .stringAttributeType

        let spanAttributeValueAttribute = NSAttributeDescription()
        spanAttributeValueAttribute.name = "value"
        spanAttributeValueAttribute.attributeType = .stringAttributeType

        let spanAttributesParentRelationship = NSRelationshipDescription()
        let spantAttributesChildRelationship = NSRelationshipDescription()

        spanAttributesParentRelationship.name = "attributes"
        spanAttributesParentRelationship.deleteRule = .cascadeDeleteRule
        spanAttributesParentRelationship.destinationEntity = attributes
        spanAttributesParentRelationship.inverseRelationship = spantAttributesChildRelationship

        spantAttributesChildRelationship.name = "span"
        spantAttributesChildRelationship.minCount = 1
        spantAttributesChildRelationship.maxCount = 1
        spantAttributesChildRelationship.destinationEntity = entity
        spantAttributesChildRelationship.inverseRelationship = spanAttributesParentRelationship

        // event
        let eventNameAttribute = NSAttributeDescription()
        eventNameAttribute.name = "name"
        eventNameAttribute.attributeType = .stringAttributeType

        let eventTimestampAttribute = NSAttributeDescription()
        eventTimestampAttribute.name = "timestamp"
        eventTimestampAttribute.attributeType = .dateAttributeType
        eventTimestampAttribute.defaultValue = Date()

        let eventParentRelationship = NSRelationshipDescription()
        let eventChildRelationship = NSRelationshipDescription()

        eventParentRelationship.name = "events"
        eventParentRelationship.deleteRule = .cascadeDeleteRule
        eventParentRelationship.destinationEntity = events
        eventParentRelationship.inverseRelationship = eventChildRelationship

        eventChildRelationship.name = "span"
        eventChildRelationship.minCount = 1
        eventChildRelationship.maxCount = 1
        eventChildRelationship.destinationEntity = entity
        eventChildRelationship.inverseRelationship = eventParentRelationship

        // event attributes
        let eventAttributeKeyAttribute = NSAttributeDescription()
        eventAttributeKeyAttribute.name = "key"
        eventAttributeKeyAttribute.attributeType = .stringAttributeType

        let eventAttributeValueAttribute = NSAttributeDescription()
        eventAttributeValueAttribute.name = "value"
        eventAttributeValueAttribute.attributeType = .stringAttributeType

        let eventAttributesParentRelationship = NSRelationshipDescription()
        let eventAttributesChildRelationship = NSRelationshipDescription()

        eventAttributesParentRelationship.name = "attributes"
        eventAttributesParentRelationship.deleteRule = .cascadeDeleteRule
        eventAttributesParentRelationship.destinationEntity = eventAttributes
        eventAttributesParentRelationship.inverseRelationship = eventAttributesChildRelationship

        eventAttributesChildRelationship.name = "event"
        eventAttributesChildRelationship.minCount = 1
        eventAttributesChildRelationship.maxCount = 1
        eventAttributesChildRelationship.destinationEntity = events
        eventAttributesChildRelationship.inverseRelationship = eventAttributesParentRelationship

        // link
        let linkSpanIdAttribute = NSAttributeDescription()
        linkSpanIdAttribute.name = "spanId"
        linkSpanIdAttribute.attributeType = .stringAttributeType

        let linkTraceIdAttribute = NSAttributeDescription()
        linkTraceIdAttribute.name = "traceId"
        linkTraceIdAttribute.attributeType = .stringAttributeType

        let linkParentRelationship = NSRelationshipDescription()
        let linkChildRelationship = NSRelationshipDescription()

        linkParentRelationship.name = "links"
        linkParentRelationship.deleteRule = .cascadeDeleteRule
        linkParentRelationship.destinationEntity = links
        linkParentRelationship.inverseRelationship = eventChildRelationship

        linkChildRelationship.name = "span"
        linkChildRelationship.minCount = 1
        linkChildRelationship.maxCount = 1
        linkChildRelationship.destinationEntity = entity
        linkChildRelationship.inverseRelationship = eventParentRelationship

        // link attributes
        let linkAttributeKeyAttribute = NSAttributeDescription()
        linkAttributeKeyAttribute.name = "key"
        linkAttributeKeyAttribute.attributeType = .stringAttributeType

        let linkAttributeValueAttribute = NSAttributeDescription()
        linkAttributeValueAttribute.name = "value"
        linkAttributeValueAttribute.attributeType = .stringAttributeType

        let linkAttributesParentRelationship = NSRelationshipDescription()
        let linkAttributesChildRelationship = NSRelationshipDescription()

        linkAttributesParentRelationship.name = "attributes"
        linkAttributesParentRelationship.deleteRule = .cascadeDeleteRule
        linkAttributesParentRelationship.destinationEntity = eventAttributes
        linkAttributesParentRelationship.inverseRelationship = linkAttributesParentRelationship

        linkAttributesChildRelationship.name = "link"
        linkAttributesChildRelationship.minCount = 1
        linkAttributesChildRelationship.maxCount = 1
        linkAttributesChildRelationship.destinationEntity = links
        linkAttributesChildRelationship.inverseRelationship = linkAttributesChildRelationship

        // result
        entity.properties = [
            idAttribute,
            traceIdAttribute,
            parentSpanIdAttribute,
            nameAttribute,
            typeAttribute,
            statusAttribute,
            startTimeAttribute,
            endTimeAttribute,
            sessionIdAttribute,
            processIdAttribute,
            eventParentRelationship,
            linkParentRelationship,
            spanAttributesParentRelationship
        ]

        attributes.properties = [
            spanAttributeKeyAttribute,
            spanAttributeValueAttribute,
            spantAttributesChildRelationship
        ]

        events.properties = [
            eventNameAttribute,
            eventTimestampAttribute,
            eventAttributesParentRelationship,
            eventChildRelationship
        ]

        eventAttributes.properties = [
            eventAttributeKeyAttribute,
            eventAttributeValueAttribute,
            eventAttributesChildRelationship
        ]

        links.properties = [
            linkSpanIdAttribute,
            linkTraceIdAttribute,
            linkAttributesParentRelationship,
            linkChildRelationship
        ]

        linkAttributes.properties = [
            linkAttributeKeyAttribute,
            linkAttributeValueAttribute,
            linkAttributesChildRelationship
        ]

        return [
            entity,
            attributes,
            events,
            eventAttributes,
            links,
            linkAttributes
        ]
    }
}

struct ImmutableSpanRecord: EmbraceSpan {
    let id: String
    let traceId: String
    let parentSpanId: String?
    let name: String
    let type: EmbraceType
    let status: EmbraceSpanStatus
    let startTime: Date
    let endTime: Date?
    let sessionId: EmbraceIdentifier?
    let processId: EmbraceIdentifier
    let events: [EmbraceSpanEvent]
    let links: [EmbraceSpanLink]
    let attributes: [String: String]

    func setStatus(_ status: EmbraceSpanStatus) {
        // no op
    }

    func addEvent(_ event: any EmbraceSemantics.EmbraceSpanEvent) {
        // no op
    }

    func addLink(_ link: any EmbraceSemantics.EmbraceSpanLink) {
        // no op
    }

    func end(endTime: Date) {
        // no op
    }

    func end() {
        // no op
    }

    func setAttribute(key: String, value: String?) {
        // no op
    }
}
