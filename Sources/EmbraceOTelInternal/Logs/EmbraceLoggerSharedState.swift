//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetryApi
import OpenTelemetrySdk
import Foundation

public protocol EmbraceLogSharedState {
    var processors: [LogRecordProcessor] { get }
    var config: any EmbraceLoggerConfig { get }
    var resourceProvider: EmbraceResourceProvider { get }

    func update(_ config: any EmbraceLoggerConfig)
}
