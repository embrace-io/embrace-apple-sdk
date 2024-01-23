//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetryApi
import OpenTelemetrySdk
import Foundation

class EmbraceLoggerSharedState {
    let resource: Resource
    let processors: [LogRecordProcessor]
    private(set) var config: EmbraceLoggerConfig

    init(resource: Resource,
         config: EmbraceLoggerConfig,
         processors: [LogRecordProcessor]) {
        self.resource = resource
        self.config = config
        self.processors = processors
    }

    static func `default`() -> EmbraceLoggerSharedState {
        .init(resource: .init(),
              config: DefaultEmbraceLoggerConfig(),
              processors: [])
    }

    func update(_ config: EmbraceLoggerConfig) {
        self.config = config
    }
}
