//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetrySdk

/// This provider allows to dependents to decide which resource they should expose or not
/// as an `OpenTelemetryApi.Resource`. Mapping to the actual `Resource` object
/// is being done internally in `EmbraceOTel`.
public protocol EmbraceResourceProvider {
    func getResources() -> [EmbraceResource]
}

extension EmbraceResourceProvider {
    public func getResource() -> Resource {
        var attributes: [String: AttributeValue] = [:]

        getResources().forEach {
            attributes[$0.key] = $0.value
        }

        if attributes[ResourceAttributes.serviceName.rawValue] == nil {
            let serviceName = [Bundle.main.bundleIdentifier, ProcessInfo.processInfo.processName]
                .compactMap { $0 }
                .joined(separator: ":")

            attributes[ResourceAttributes.serviceName.rawValue] = .string(serviceName)
        }

        if attributes[ResourceAttributes.telemetrySdkLanguage.rawValue] == nil {
            attributes[ResourceAttributes.telemetrySdkLanguage.rawValue] = .string("swift")
        }

        return Resource(attributes: attributes)
    }
}
