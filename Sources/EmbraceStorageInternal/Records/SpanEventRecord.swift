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
    @NSManaged public var timestamp: Date
    @NSManaged public var attributes: Set<SpanEventAttributeRecord>
    @NSManaged public var span: SpanRecord?

    class func create(
        context: NSManagedObjectContext,
        name: String,
        timestamp: Date,
        attributes: [String: String],
        span: SpanRecord?
    ) -> SpanEventRecord? {
        var result: SpanEventRecord?

        context.performAndWait {
            guard let description = NSEntityDescription.entity(forEntityName: Self.entityName, in: context) else {
                return
            }

            let record = SpanEventRecord(entity: description, insertInto: context)
            record.name = name
            record.timestamp = timestamp
            record.span = span
            record.attributes = Set()

            for (key, value) in attributes {
                if let attribute = SpanEventAttributeRecord.create(
                    context: context,
                    key: key,
                    value: value,
                    event: record
                ) {
                    record.attributes.insert(attribute)
                }
            }

            result = record
        }

        return result
    }

    func toImmutable() -> EmbraceSpanEvent {

        let finalAttributes = attributes.reduce(into: [String: String]()) {
            $0[$1.key] = $1.value
        }

        return ImmutableSpanEventRecord(
            name: name,
            timestamp: timestamp,
            attributes: finalAttributes
        )
    }
}

extension SpanEventRecord: EmbraceStorageRecord {
    public static var entityName = "SpanEventRecord"
}

struct ImmutableSpanEventRecord: EmbraceSpanEvent {
    let name: String
    let timestamp: Date
    let attributes: [String: String]

    func setAttribute(key: String, value: String?) {
        // no op
    }
}
