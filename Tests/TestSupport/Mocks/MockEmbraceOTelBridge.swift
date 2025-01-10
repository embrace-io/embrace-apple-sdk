//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
@testable import EmbraceOTelInternal
import EmbraceCommonInternal
import OpenTelemetryApi
import OpenTelemetrySdk

public class MockEmbraceOTelBridge: EmbraceOTelBridge {

    public let otel = MockEmbraceOpenTelemetry()

    public init() {}

    public func buildSpan(name: String, type: SpanType, attributes: [String : String]) -> any SpanBuilder {
        return otel.buildSpan(name: name, type: type, attributes: attributes)
    }
    
    public func log(_ message: String, severity: LogSeverity, timestamp: Date, attributes: [String : String]) {
        otel.log(message, severity: severity, timestamp: timestamp, attributes: attributes)
    }
}
