//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import CoreData
import Foundation

@objc(SpanEventAttributeRecord)
public class SpanEventAttributeRecord: NSManagedObject {
    @NSManaged public var key: String
    @NSManaged public var value: String
    @NSManaged public var event: SpanEventRecord?

    class func create(
        context: NSManagedObjectContext,
        key: String,
        value: String,
        event: SpanEventRecord?
    ) -> SpanEventAttributeRecord? {
        var record: SpanEventAttributeRecord?

        context.performAndWait {
            guard let description = NSEntityDescription.entity(forEntityName: Self.entityName, in: context) else {
                return
            }

            record = SpanEventAttributeRecord(entity: description, insertInto: context)
            record?.key = key
            record?.value = value
            record?.event = event
        }

        return record
    }
}

extension SpanEventAttributeRecord: EmbraceStorageRecord {
    public static var entityName = "SpanEventAttributeRecord"
}
