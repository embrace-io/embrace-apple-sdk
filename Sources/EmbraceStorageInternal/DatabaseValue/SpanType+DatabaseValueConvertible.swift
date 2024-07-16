//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import GRDB
import EmbraceCommonInternal

extension SpanType: DatabaseValueConvertible {
    public var databaseValue: DatabaseValue {
        return String(rawValue).databaseValue
    }

    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> SpanType? {
        guard let rawValue = String.fromDatabaseValue(dbValue) else {
            return nil
        }

        return SpanType(rawValue: rawValue)
    }
}
