//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

extension MetadataRecord {

    public var boolValue: Bool? {
        switch value {
        case .bool(let bool): return bool
        case .int(let integer): return integer > 0
        case .double(let double): return double > 0
        case .string(let string): return Bool(string)
        default: return nil
        }
    }

    public var integerValue: Int? {
        switch value {
        case .bool(let bool): return bool ? 1 : 0
        case .int(let integer): return integer
        case .double(let double): return Int(double)
        case .string(let string): return Int(string)
        default: return nil
        }
    }

    public var doubleValue: Double? {
        switch value {
        case .bool(let bool): return bool ? 1 : 0
        case .int(let integer): return Double(integer)
        case .double(let double): return double
        case .string(let string): return Double(string)
        default: return nil
        }
    }

    public var stringValue: String? {
        switch value {
        case .bool(let bool): return String(bool)
        case .int(let integer): return String(integer)
        case .double(let double): return String(double)
        case .string(let string): return string
        default: return nil
        }
    }

    public var uuidValue: UUID? {
        switch value {
        case .string(let string): return UUID(withoutHyphen: string)
        default: return nil
        }
    }
}
