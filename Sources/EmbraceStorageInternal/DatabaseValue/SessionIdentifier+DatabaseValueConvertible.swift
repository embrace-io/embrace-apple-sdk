//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import GRDB

extension SessionIdentifier: DatabaseValueConvertible {
    public var databaseValue: DatabaseValue {
        return toString.databaseValue
    }

    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> SessionIdentifier? {
        guard let uuidString = String.fromDatabaseValue(dbValue) else {
            return nil
        }

        return SessionIdentifier(string: uuidString)
    }
}
