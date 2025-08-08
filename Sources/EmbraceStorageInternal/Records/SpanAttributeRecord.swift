//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import CoreData
import Foundation

@objc(SpanAttributeRecord)
public class SpanAttributeRecord: NSManagedObject {
    @NSManaged public var key: String
    @NSManaged public var value: String
    @NSManaged public var span: SpanRecord?

    class func create(
        context: NSManagedObjectContext,
        key: String,
        value: String,
        span: SpanRecord?
    ) -> SpanAttributeRecord? {
        var record: SpanAttributeRecord?

        context.performAndWait {
            guard let description = NSEntityDescription.entity(forEntityName: Self.entityName, in: context) else {
                return
            }

            record = SpanAttributeRecord(entity: description, insertInto: context)
            record?.key = key
            record?.value = value
            record?.span = span
        }

        return record
    }
}

extension SpanAttributeRecord: EmbraceStorageRecord {
    public static var entityName = "SpanAttributeRecord"
}
