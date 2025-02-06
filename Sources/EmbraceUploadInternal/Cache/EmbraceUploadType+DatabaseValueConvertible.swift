//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import GRDB

extension EmbraceUploadType: DatabaseValueConvertible {
    var databaseValue: DatabaseValue {
        return self.rawValue.databaseValue
    }

    static func fromDatabaseValue(_ dbValue: DatabaseValue) -> EmbraceUploadType? {
        guard let rawValue = Int.fromDatabaseValue(dbValue) else {
            return nil
        }
        return EmbraceUploadType(rawValue: rawValue)
    }
}
