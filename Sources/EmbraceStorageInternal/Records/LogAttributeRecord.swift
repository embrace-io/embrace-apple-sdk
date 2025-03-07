//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import CoreData
import EmbraceCommonInternal
import OpenTelemetryApi

@objc(LogAttributeRecord)
public class LogAttributeRecord: NSManagedObject, EmbraceLogAttribute {
    @NSManaged public var key: String
    @NSManaged public var valueRaw: String
    @NSManaged public var typeRaw: Int // LogAttributeType
    @NSManaged public var log: LogRecord

    public static func create(
        context: NSManagedObjectContext,
        key: String,
        value: AttributeValue,
        log: LogRecord
    ) -> LogAttributeRecord? {
        guard let description = NSEntityDescription.entity(forEntityName: Self.entityName, in: context) else {
            return nil
        }

        var record = LogAttributeRecord(entity: description, insertInto: context)
        record.key = key
        record.value = value
        record.log = log

        return record
    }
}

extension LogAttributeRecord: EmbraceStorageRecord {
    public static var entityName = "LogAttributeRecord"
}
