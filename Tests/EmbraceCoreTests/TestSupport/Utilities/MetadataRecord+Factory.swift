//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceStorageInternal
import EmbraceCommonInternal
import OpenTelemetryApi

extension MetadataRecord {
    static func createSessionPropertyRecord(
        key: String,
        value: AttributeValue,
        sessionId: SessionIdentifier = .random
    ) -> MetadataRecord {
        self.init(
            key: key,
            value: value,
            type: .customProperty,
            lifespan: .session,
            lifespanId: sessionId.toString
        )
    }

    static func userMetadata(key: String, value: String) -> MetadataRecord {
        .init(
            key: key,
            value: .string(value),
            type: .customProperty,
            lifespan: .session,
            lifespanId: .random()
        )
    }

    static func createResourceRecord(key: String, value: String) -> MetadataRecord {
        .init(
            key: key,
            value: .string(value),
            type: .resource,
            lifespan: .session,
            lifespanId: .random()
        )
    }
}
