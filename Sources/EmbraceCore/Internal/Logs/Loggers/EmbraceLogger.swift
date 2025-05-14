//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceCommonInternal
import EmbraceOTelInternal
import EmbraceConfiguration
#endif

protocol EmbraceInternalLogger: InternalLogger {
    var level: LogLevel { get set }
    var otel: EmbraceOpenTelemetry? { get set }
    var limits: InternalLogLimits { get set }
}
