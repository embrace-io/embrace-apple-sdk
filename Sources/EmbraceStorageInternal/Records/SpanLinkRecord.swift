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
    @NSManaged public var attributes: String
    @NSManaged public var span: SpanRecord?

    class func create(
        context: NSManagedObjectContext,
        link: EmbraceSpanLink,
        span: SpanRecord?
    ) -> SpanLinkRecord? {
        var result: SpanLinkRecord?

        context.performAndWait {
            guard let description = NSEntityDescription.entity(forEntityName: Self.entityName, in: context) else {
                return
            }

            let record = SpanLinkRecord(entity: description, insertInto: context)
            record.span = span
            record.update(
                spanId: link.context.spanId,
                traceId: link.context.traceId,
                attributes: link.attributes
            )

            result = record
        }

        return result
    }

    func update(spanId: String, traceId: String, attributes: [String: String]) {
        self.spanId = spanId
        self.traceId = traceId
        self.attributes = attributes.keyValueEncoded()
    }

    func toImmutable() -> EmbraceSpanLink {
        return EmbraceSpanLink(
            spanId: spanId,
            traceId: traceId,
            attributes: .keyValueDecode(attributes)
        )
    }
}

extension SpanLinkRecord: EmbraceStorageRecord {
    public static var entityName = "SpanLinkRecord"
}

