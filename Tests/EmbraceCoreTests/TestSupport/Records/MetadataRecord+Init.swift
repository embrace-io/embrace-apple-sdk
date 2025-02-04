//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal
import EmbraceStorageInternal

extension MetadataRecord {
    convenience init(
        key: String,
        value: String,
        type: MetadataRecordType,
        lifespan: MetadataRecordLifespan,
        lifespanId: String,
        collectedAt: Date = Date()
    ) {
        self.init()

        self.key = key
        self.value = value
        self.typeRaw = type.rawValue
        self.lifespanRaw = lifespan.rawValue
        self.lifespanId = lifespanId
        self.collectedAt = collectedAt
    }
}


