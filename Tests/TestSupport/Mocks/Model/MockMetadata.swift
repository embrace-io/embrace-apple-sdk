//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import Foundation
import OpenTelemetryApi

public class MockMetadata: EmbraceMetadata {
    public var key: String
    public var value: String
    public var typeRaw: String
    public var lifespanRaw: String
    public var lifespanId: String
    public var collectedAt: Date

    public init(
        key: String,
        value: String,
        type: MetadataRecordType,
        lifespan: MetadataRecordLifespan,
        lifespanId: String = "",
        collectedAt: Date = Date()
    ) {
        self.key = key
        self.value = value
        self.typeRaw = type.rawValue
        self.lifespanRaw = lifespan.rawValue
        self.lifespanId = lifespanId
        self.collectedAt = collectedAt
    }
}

extension MockMetadata {
    public static func createSessionPropertyRecord(
        key: String,
        value: AttributeValue,
        sessionId: EmbraceIdentifier = .random
    ) -> EmbraceMetadata {
        MockMetadata(
            key: key,
            value: value.description,
            type: .customProperty,
            lifespan: .session,
            lifespanId: sessionId.stringValue
        )
    }

    public static func createUserMetadata(key: String, value: String) -> EmbraceMetadata {
        MockMetadata(
            key: key,
            value: value,
            type: .customProperty,
            lifespan: .session,
            lifespanId: EmbraceIdentifier.random.stringValue
        )
    }

    public static func createResourceRecord(key: String, value: String) -> EmbraceMetadata {
        MockMetadata(
            key: key,
            value: value,
            type: .resource,
            lifespan: .session,
            lifespanId: EmbraceIdentifier.random.stringValue
        )
    }

    public static func createPersonaTagRecord(value: String) -> EmbraceMetadata {
        MockMetadata(
            key: value,
            value: value,
            type: .personaTag,
            lifespan: .session,
            lifespanId: EmbraceIdentifier.random.stringValue
        )
    }
}
