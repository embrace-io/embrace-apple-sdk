//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import CoreData
import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

@objc(SpanEventRecord)
public class SpanEventRecord: NSManagedObject {
    @NSManaged public var name: String
    @NSManaged public var timestamp: Date
    @NSManaged public var attributesData: Data
    @NSManaged public var span: SpanRecord?

    class func create(
        context: NSManagedObjectContext,
        name: String,
        timestamp: Date,
        attributes: [String: String],
        span: SpanRecord?
    ) -> SpanEventRecord? {
        nonisolated(unsafe) var result: SpanEventRecord?
        nonisolated(unsafe) let spanRecord: SpanRecord? = span

        context.performAndWait {
            guard let description = NSEntityDescription.entity(forEntityName: Self.entityName, in: context) else {
                return
            }

            let record = SpanEventRecord(entity: description, insertInto: context)
            record.name = name
            record.timestamp = timestamp
            record.setAttributes(attributes)
            record.span = spanRecord

            result = record
        }

        return result
    }

    func setAttributes(_ attributes: [String: String]) {
        if let data = try? JSONEncoder().encode(attributes) {
            attributesData = data
        } else {
            attributesData = Data()
        }
    }

    func getAttributes() -> [String: String] {
        if let attributes = try? JSONDecoder().decode([String: String].self, from: attributesData) {
            return attributes
        }
        return [:]
    }

    func toImmutable() -> EmbraceSpanEvent {
        return ImmutableSpanEventRecord(name: name, timestamp: timestamp, attributes: getAttributes())
    }

    static func createFetchRequest() -> NSFetchRequest<SpanEventRecord> {
        return NSFetchRequest<SpanEventRecord>(entityName: entityName)
    }
}

extension SpanEventRecord: EmbraceStorageRecord {
    public static let entityName = "SpanEventRecord"
}

package struct ImmutableSpanEventRecord: EmbraceSpanEvent {
    package let name: String
    package let timestamp: Date
    package let attributes: [String: String]

    package init(name: String, timestamp: Date, attributes: [String: String]) {
        self.name = name
        self.timestamp = timestamp
        self.attributes = attributes
    }
}
