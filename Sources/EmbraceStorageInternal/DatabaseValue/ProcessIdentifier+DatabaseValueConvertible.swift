//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceCommonInternal
#endif
import GRDB

extension ProcessIdentifier: DatabaseValueConvertible {
    public var databaseValue: DatabaseValue {
        return String(hex).databaseValue
    }

    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> ProcessIdentifier? {
        guard let hex = String.fromDatabaseValue(dbValue) else {
            return nil
        }

        return ProcessIdentifier(hex: hex)
    }
}
