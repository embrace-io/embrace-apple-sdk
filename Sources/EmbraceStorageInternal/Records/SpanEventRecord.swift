//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import CoreData
import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

@objc(SpanEventRecord)
public class SpanEventRecord: NSManagedObject {
    @NSManaged public var name: String
    @NSManaged public var typeRaw: String
    @NSManaged public var timestamp: Date
    @NSManaged public var attributes: String
    @NSManaged public var span: SpanRecord?

    class func create(
        context: NSManagedObjectContext,
        event: EmbraceSpanEvent,
        span: SpanRecord?
    ) -> SpanEventRecord? {
        var result: SpanEventRecord?

        context.performAndWait {
            guard let description = NSEntityDescription.entity(forEntityName: Self.entityName, in: context) else {
                return
            }

            let record = SpanEventRecord(entity: description, insertInto: context)
            record.span = span
            record.typeRaw = event.type.rawValue
            record.update(
                name: event.name,
                timestamp: event.timestamp,
                attributes: event.attributes
            )

            result = record
        }

        return result
    }

    func update(name: String, timestamp: Date, attributes: [String: String]) {
        self.name = name
        self.timestamp = timestamp
        self.attributes = attributes.keyValueEncoded()
    }

    func toImmutable() -> EmbraceSpanEvent {
        return EmbraceSpanEvent(
            name: name,
            type: EmbraceType(rawValue: typeRaw) ?? .performance,
            timestamp: timestamp,
            attributes: .keyValueDecode(attributes)
        )
    }
}

extension SpanEventRecord: EmbraceStorageRecord {
    public static var entityName = "SpanEventRecord"
}
