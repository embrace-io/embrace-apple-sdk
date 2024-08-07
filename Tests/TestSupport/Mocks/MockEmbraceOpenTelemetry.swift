//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
@testable import EmbraceOTelInternal
@testable import EmbraceCore
import EmbraceCommonInternal
import OpenTelemetryApi
import OpenTelemetrySdk

public class MockEmbraceOpenTelemetry: NSObject, EmbraceOpenTelemetry {
    private(set) public var spanProcessor = MockSpanProcessor()
    private(set) public var events: [SpanEvent] = []
    private(set) public var logs: [ReadableLogRecord] = []

    public override init() {
        EmbraceOTel.setup(spanProcessors: [spanProcessor])
    }

    public func clear() {
        spanProcessor = MockSpanProcessor()
        events = []
        logs = []
    }

    public func buildSpan(
        name: String,
        type: SpanType,
        attributes: [String: String]) -> SpanBuilder {

        return EmbraceOTel()
            .buildSpan(name: name, type: type, attributes: attributes)
    }

    public func recordCompletedSpan(
        name: String,
        type: SpanType,
        parent: Span?,
        startTime: Date,
        endTime: Date,
        attributes: [String: String],
        events: [RecordingSpanEvent],
        errorCode: ErrorCode? ) {

    }

    public func add(events: [SpanEvent]) {
        self.events.append(contentsOf: events)
    }

    public func add(event: SpanEvent) {
        events.append(event)
    }

    public func log(
        _ message: String,
        severity: LogSeverity,
        type: LogType = .message,
        attributes: [String: String]
    ) {
        log(message, severity: severity, type: type, timestamp: Date(), attributes: attributes)
    }

    public func log(
        _ message: String,
        severity: LogSeverity,
        type: LogType = .message,
        timestamp: Date,
        attributes: [String: String]
    ) {

        var otelAttributes: [String: AttributeValue] = [:]
        for (key, value) in attributes {
            otelAttributes[key] = .string(value)
        }

        let log = ReadableLogRecord(
            resource: .init(),
            instrumentationScopeInfo: .init(),
            timestamp: timestamp,
            severity: Severity.fromLogSeverity(severity),
            body: message,
            attributes: otelAttributes
        )

        logs.append(log)
    }
}
