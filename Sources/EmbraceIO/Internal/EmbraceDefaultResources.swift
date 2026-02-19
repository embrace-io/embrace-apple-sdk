//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

enum EmbraceDefaultResources {

    /// Builds an OTel `Resource` containing Embrace's standard default attributes, with the
    /// optional user-provided resource merged on top so that user values always win.
    ///
    /// Default attributes set by Embrace:
    /// - `service.name`: `<bundleId>:<processName>` (or just `<processName>` if no bundle ID)
    /// - `service.version`: `CFBundleShortVersionString` from the main bundle (omitted if absent)
    /// - `telemetry.sdk.language`: `"swift"`
    static func build(merging userResource: Resource? = nil) -> Resource {
        let serviceName = [Bundle.main.bundleIdentifier, ProcessInfo.processInfo.processName]
            .compactMap { $0 }
            .joined(separator: ":")

        var attributes: [String: AttributeValue] = [
            "service.name": .string(serviceName),
            "telemetry.sdk.language": .string("swift")
        ]

        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            attributes["service.version"] = .string(version)
        }

        var result = Resource(attributes: attributes)

        if let userResource {
            result.merge(other: userResource)
        }

        return result
    }
}
