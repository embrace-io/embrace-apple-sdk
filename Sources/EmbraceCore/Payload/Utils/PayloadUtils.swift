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
    ) -> [MetadataRecord] {

        guard let sessionId = sessionId else {
            return []
        }

        do {
            return try fetcher.fetchResourcesForSessionId(sessionId)
        } catch let e {
            Embrace.logger.error("Failed to fetch resource records from storage: \(e.localizedDescription)")
        }

        return []
    }

    static func fetchCustomProperties(
        from fetcher: EmbraceStorageMetadataFetcher,
        sessionId: SessionIdentifier?
    ) -> [MetadataRecord] {

        guard let sessionId = sessionId else {
            return []
        }

        do {
            return try fetcher.fetchCustomPropertiesForSessionId(sessionId)
        } catch let e {
            Embrace.logger.error("Failed to fetch custom properties from storage: \(e.localizedDescription)")
        }

        return []
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
