//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import CoreData
import EmbraceCommonInternal
import OpenTelemetryApi

@objc(LogAttributeRecord)
public class LogAttributeRecord: NSManagedObject {
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
            record?.setValue(value)
            record?.log = log
        }

        return record
    }

    func setValue(_ value: AttributeValue) {
        valueRaw = value.description
        typeRaw = typeForValue(value).rawValue
    }

    func typeForValue(_ value: AttributeValue) -> EmbraceLogAttributeType {
        switch value {
        case .int: return .int
        case .double: return .double
        case .bool: return .bool
        default: return .string
        }
    }

    func toImmutable() -> EmbraceLogAttribute {
        return ImmutableLogAttributeRecord(
            key: key,
            valueRaw: valueRaw,
            typeRaw: typeRaw
        )
    }
}

extension LogAttributeRecord: EmbraceStorageRecord {
    public static var entityName = "LogAttributeRecord"
}

struct ImmutableLogAttributeRecord: EmbraceLogAttribute {
    let key: String
    let valueRaw: String
    let typeRaw: Int
}
