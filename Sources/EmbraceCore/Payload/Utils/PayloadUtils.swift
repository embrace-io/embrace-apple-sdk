//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommon
import EmbraceStorage
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
            ConsoleLog.error("Failed to fetch resource records from storage: \(e.localizedDescription)")
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
            ConsoleLog.error("Failed to fetch custom properties from storage: \(e.localizedDescription)")
        }

        return []
    }

    static func convertSpanAttributes(_ attributes: [String: AttributeValue]) -> [String: Any] {
        var result: [String: Any] = [:]

        for (key, value) in attributes {
            switch value {
            case .bool(let boolValue): result[key] = boolValue
            case .double(let doubleValue): result[key] = doubleValue
            case .int(let intValue): result[key] = intValue
            case .string(let stringValue): result[key] = stringValue
            default: continue
            }
        }

        return result
    }
}
