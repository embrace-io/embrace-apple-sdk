//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommon
import EmbraceStorage
import OpenTelemetryApi

class PayloadUtils {
    static func fetchResources(from fetcher: EmbraceStorageResourceFetcher, sessionId: String?) -> [ResourceRecord] {
        guard let sessionId = sessionId else { return [] }

        do {
            let resources = try fetcher.fetchAllResourceForSession(sessionId: sessionId) ?? []
            return resources
        } catch let e {
            ConsoleLog.error("Failed to fetch resource records from storage: \(e.localizedDescription)")
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
