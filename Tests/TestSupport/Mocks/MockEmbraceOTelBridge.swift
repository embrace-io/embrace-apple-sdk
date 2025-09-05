//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceSemantics
import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

@testable import EmbraceOTelInternal

public class MockEmbraceOTelBridge: EmbraceOTelBridge {

    public let otel = MockEmbraceOpenTelemetry()

    public init() {}

    public func buildSpan(name: String, type: EmbraceType, attributes: [String: String]) -> any SpanBuilder {
        return otel.buildSpan(name: name, type: type, attributes: attributes)
    }

    public func log(_ message: String, severity: EmbraceLogSeverity, timestamp: Date, attributes: [String: String]) {
        otel.log(message, severity: severity, timestamp: timestamp, attributes: attributes)
    }
}
