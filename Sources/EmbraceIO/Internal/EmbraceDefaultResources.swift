//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

enum EmbraceDefaultResources {

    /// Builds an OTel `Resource` containing Embrace's standard default attributes, merged with the
    /// optional user-provided resource.
    ///
    /// User values are kept for any attribute they define, except for the default attributes listed
    /// below: those are always set by Embrace and take precedence over any colliding user value, so
    /// they can't be overriden externally.
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

        let embraceResources = Resource(attributes: attributes)

        if var resources = userResource {
            resources.merge(other: embraceResources)
            return resources
        }

        return embraceResources
    }
}
