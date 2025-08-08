//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import CoreData
import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

@objc(SpanLinkRecord)
public class SpanLinkRecord: NSManagedObject {
    @NSManaged public var spanId: String
    @NSManaged public var traceId: String
    @NSManaged public var attributes: Set<SpanLinkAttributeRecord>
    @NSManaged public var span: SpanRecord?

    class func create(
        context: NSManagedObjectContext,
        spanId: String,
        traceId: String,
        attributes: [String: String],
        span: SpanRecord?
    ) -> SpanLinkRecord? {
        var result: SpanLinkRecord?

        context.performAndWait {
            guard let description = NSEntityDescription.entity(forEntityName: Self.entityName, in: context) else {
                return
            }

            let record = SpanLinkRecord(entity: description, insertInto: context)
            record.spanId = spanId
            record.traceId = traceId
            record.span = span
            record.attributes = Set()

            for (key, value) in attributes {
                if let attribute = SpanLinkAttributeRecord.create(
                    context: context,
                    key: key,
                    value: value,
                    link: record
                ) {
                    record.attributes.insert(attribute)
                }
            }

            result = record
        }

        return result
    }

    func toImmutable() -> EmbraceSpanLink {

        let finalAttributes = attributes.reduce(into: [String: String]()) {
            $0[$1.key] = $1.value
        }

        return ImmutableSpanLinkRecord(
            spanId: spanId,
            traceId: traceId,
            attributes: finalAttributes
        )
    }
}

extension SpanLinkRecord: EmbraceStorageRecord {
    public static var entityName = "SpanLinkRecord"
}

struct ImmutableSpanLinkRecord: EmbraceSpanLink {
    let spanId: String
    let traceId: String
    let attributes: [String: String]

    func setAttribute(key: String, value: String?) {
        // no op
    }
}
