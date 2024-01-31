//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetryApi
import OpenTelemetrySdk
import Foundation

/// Typealias created to abstract away the `AttributeValue` from `OpenTelemetryApi`,
/// reducing the dependency exposure to dependents.
public typealias ResourceValue = AttributeValue

// This representation of the `Resource` concept was necessary because the
// logReadeableRecord needs it.
public protocol EmbraceResource {
    var key: String { get }
    var value: ResourceValue { get }
}

/// This provider allows to dependents to decide which resource they should expose or not
/// as an `OpenTelemetryApi.Resource`. Mapping to the actual `Resource` object
/// is being done internally in `EmbraceOTel`.
public protocol ResourceProvider {
    func getResources() -> [EmbraceResource]
}

public protocol EmbraceLogSharedState {
    var processors: [LogRecordProcessor] { get }
    var config: any EmbraceLoggerConfig { get }
    var resourceProvider: ResourceProvider { get }

    func update(_ config: any EmbraceLoggerConfig)
}

extension EmbraceLogSharedState {
    func getResource() -> Resource {
        var attributes: [String: AttributeValue] = [:]
        resourceProvider.getResources().forEach {
            attributes[$0.key] = $0.value
        }
        return Resource(attributes: attributes)
    }
}
