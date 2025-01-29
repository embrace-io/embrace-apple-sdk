//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import CoreData
import OpenTelemetryApi

public enum LogAttributeType: Int {
    case string, int, double, bool
}

public class LogAttributeRecord: NSManagedObject {
    @NSManaged public var key: String
    @NSManaged public var valueRaw: String
    @NSManaged public var typeRaw: Int // LogAttributeType
    @NSManaged public var log: LogRecord

    public var value: AttributeValue {
        get {
            let type = LogAttributeType(rawValue: typeRaw) ?? .string

            switch  type {
            case .int: return AttributeValue(Int(valueRaw) ?? 0)
            case .double: return AttributeValue(Double(valueRaw) ?? 0)
            case .bool: return AttributeValue(Bool(valueRaw) ?? false)
            default: return AttributeValue(valueRaw)
            }
        }

        set {
            valueRaw = newValue.description
            typeRaw = Self.typeForValue(newValue).rawValue
        }
    }

    public static func create(
        context: NSManagedObjectContext,
        key: String,
        value: AttributeValue,
        log: LogRecord
    ) -> LogAttributeRecord {
        let record = LogAttributeRecord(context: context)
        record.key = key
        record.value = value
        record.log = log

        return record
    }

    private static func typeForValue(_ value: AttributeValue) -> LogAttributeType {
        switch value {
        case .int(_): return .int
        case .double(_): return .double
        case .bool(_): return .bool
        default: return .string
        }
    }
}

extension LogAttributeRecord: EmbraceStorageRecord {
    public static var entityName = "LogAttributeRecord"
}
