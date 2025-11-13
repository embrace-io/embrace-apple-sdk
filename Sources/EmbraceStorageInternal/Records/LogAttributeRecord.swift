//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import CoreData
import Foundation
@preconcurrency import OpenTelemetryApi

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

@objc(LogAttributeRecord)
public class LogAttributeRecord: NSManagedObject {
    @NSManaged public var key: String
    @NSManaged public var valueRaw: String
    @NSManaged public var typeRaw: Int  // LogAttributeType
    @NSManaged public var log: LogRecord?

    class func create(
        context: NSManagedObjectContext,
        key: String,
        value: AttributeValue,
        log: LogRecord?
    ) -> LogAttributeRecord? {
        // Safe: `performAndWait` executes this closure synchronously on the context's queue.
        nonisolated(unsafe) var result: LogAttributeRecord?
        let logId = log?.objectID

        context.performAndWait {
            guard let description = NSEntityDescription.entity(forEntityName: Self.entityName, in: context) else {
                return
            }

            let record = LogAttributeRecord(entity: description, insertInto: context)
            record.key = key
            record.setValue(value)
            if let logId {
                record.log = try? context.existingObject(with: logId) as? LogRecord
            } else {
                record.log = nil
            }

            result = record
        }

        return result
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
    public static let entityName = "LogAttributeRecord"
}

struct ImmutableLogAttributeRecord: EmbraceLogAttribute {
    let key: String
    let valueRaw: String
    let typeRaw: Int
}
