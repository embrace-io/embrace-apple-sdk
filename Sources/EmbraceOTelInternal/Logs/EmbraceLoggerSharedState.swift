//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetryApi
import OpenTelemetrySdk
import Foundation

public protocol EmbraceLogSharedState {
    var processors: [EmbraceLogRecordProcessor] { get }
    var config: any EmbraceLoggerConfig { get }
    var resourceProvider: EmbraceResourceProvider { get }

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
