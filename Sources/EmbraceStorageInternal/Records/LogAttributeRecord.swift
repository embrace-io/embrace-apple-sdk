//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import CoreData
import EmbraceCommonInternal
import OpenTelemetryApi

@objc(EMBLogAttributeRecord)
public class LogAttributeRecord: NSManagedObject, EmbraceLogAttribute {
    @NSManaged public var key: String
    @NSManaged public var valueRaw: String
    @NSManaged public var typeRaw: Int // LogAttributeType
    @NSManaged public var log: LogRecord?

    class func create(
        context: NSManagedObjectContext,
        key: String,
        value: AttributeValue,
        log: LogRecord?
    ) -> LogAttributeRecord? {
        var record: LogAttributeRecord?

        context.performAndWait {
            guard let description = NSEntityDescription.entity(forEntityName: Self.entityName, in: context) else {
                return
            }

            record = LogAttributeRecord(entity: description, insertInto: context)
            record?.key = key
            record?.value = value
            record?.log = log
        }

        return record
    }
}

extension LogAttributeRecord: EmbraceStorageRecord {
    public static var entityName = "LogAttributeRecord"
}
