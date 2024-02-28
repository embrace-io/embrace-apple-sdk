//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
@testable import EmbraceOTel
@testable import EmbraceCore
import EmbraceCommon
import OpenTelemetryApi

class EmbraceOpenTelemetryMock: EmbraceOpenTelemetry {
    var spanProcessor: EmbraceSpanProcessor
    public var otelInstance: OpenTelemetry?

    init(processor: EmbraceSpanProcessor, otelInstance: OpenTelemetry? = nil) {
        self.spanProcessor = processor
        self.otelInstance = otelInstance

        // TODO: update callers to use otel setup directly. Should be able to remove EmbraceOpenTelemetryMock
        EmbraceOTel.setup(spanProcessors: [processor])
    }

    func buildSpan(name: String,
                   type: SpanType,
                   attributes: [String: String]) -> SpanBuilder {

        return EmbraceOTel()
            .buildSpan(name: name, type: type, attributes: attributes)
    }

    func recordCompletedSpan(
        name: String,
        type: SpanType,
        parent: Span?,
        startTime: Date,
        endTime: Date,
        attributes: [String: String],
        events: [RecordingSpanEvent],
        errorCode: ErrorCode? ) {

    }

    func add(events: [SpanEvent]) {}

    func add(event: SpanEvent) {}
}

class EmbraceOtelProviderMock: EmbraceOTelHandlingProvider {
    public var embraceOtel: EmbraceOpenTelemetryMock

    init(embraceOtel: EmbraceOpenTelemetryMock) {
        self.embraceOtel = embraceOtel
    }

    var otelHandler: EmbraceOpenTelemetry? {
        embraceOtel
    }
}
