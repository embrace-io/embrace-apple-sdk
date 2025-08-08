//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import CoreData
import Foundation

@objc(SpanLinkAttributeRecord)
public class SpanLinkAttributeRecord: NSManagedObject {
    @NSManaged public var key: String
    @NSManaged public var value: String
    @NSManaged public var link: SpanLinkRecord?

    class func create(
        context: NSManagedObjectContext,
        key: String,
        value: String,
        link: SpanLinkRecord?
    ) -> SpanLinkAttributeRecord? {
        var record: SpanLinkAttributeRecord?

        context.performAndWait {
            guard let description = NSEntityDescription.entity(forEntityName: Self.entityName, in: context) else {
                return
            }

            record = SpanLinkAttributeRecord(entity: description, insertInto: context)
            record?.key = key
            record?.value = value
            record?.link = link
        }

        return record
    }
}

extension SpanLinkAttributeRecord: EmbraceStorageRecord {
    public static var entityName = "SpanEventAttributeRecord"
}
