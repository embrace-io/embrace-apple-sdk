//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceStorageInternal
import OpenTelemetryApi

class PayloadUtils {
    static func fetchResources(
        from fetcher: EmbraceStorageMetadataFetcher,
        sessionId: SessionIdentifier?
    ) -> [EmbraceMetadata] {

        guard let sessionId = sessionId else {
            return []
        }

        return fetcher.fetchResourcesForSessionId(sessionId)
    }

    static func fetchCustomProperties(
        from fetcher: EmbraceStorageMetadataFetcher,
        sessionId: SessionIdentifier?
    ) -> [EmbraceMetadata] {

        guard let sessionId = sessionId else {
            return []
        }

        return fetcher.fetchCustomPropertiesForSessionId(sessionId)
    }

    static func convertSpanAttributes(_ attributes: [String: AttributeValue]) -> [Attribute] {
        var result: [Attribute] = []

        for (key, value) in attributes {
            switch value {
            case .boolArray, .intArray, .doubleArray, .stringArray:
                continue
            default:
                result.append(Attribute(key: key, value: value.description))
            }
        }

        return result
    }
}
