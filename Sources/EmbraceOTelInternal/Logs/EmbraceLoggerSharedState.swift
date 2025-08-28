//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

public protocol EmbraceLogSharedState {
    var processors: [LogRecordProcessor] { get }
    var config: any EmbraceLoggerConfig { get }

    func update(_ config: any EmbraceLoggerConfig)
}
