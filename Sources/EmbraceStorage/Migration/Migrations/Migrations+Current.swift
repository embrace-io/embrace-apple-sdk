//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

extension Array where Element == Migration {

    static var current: [Migration] {
        return [
            // register migrations here
            // order matters
            AddSpanRecordMigration(),
            AddSessionRecordMigration(),
            AddMetadataRecordMigration(),
            AddLogRecordMigration()
        ]
    }
}
