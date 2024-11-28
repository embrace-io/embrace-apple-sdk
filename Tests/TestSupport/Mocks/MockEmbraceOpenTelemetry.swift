//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
@testable import EmbraceOTelInternal
@testable import EmbraceCore
import EmbraceCommonInternal
import OpenTelemetryApi
import OpenTelemetrySdk
import EmbraceSemantics

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
        attributes: [String: String] = [:],
        autoTerminationCode: SpanErrorCode? = nil
    ) -> SpanBuilder {
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
        errorCode: SpanErrorCode? ) {

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
        attributes: [String: String],
        stackTraceBehavior: StackTraceBehavior = .default
    ) {
        log(
            message,
            severity: severity,
            type: type,
            timestamp: Date(),
            attributes: attributes,
            stackTraceBehavior: stackTraceBehavior
        )
    }

    public func log(
        _ message: String,
        severity: LogSeverity,
        type: LogType = .message,
        timestamp: Date,
        attributes: [String: String],
        stackTraceBehavior: StackTraceBehavior = .default
    ) {

        var attributes = attributes
        attributes["emb.type"] = type.rawValue

        var otelAttributes: [String: AttributeValue] = [:]
        for (key, value) in attributes {
            otelAttributes[key] = .string(value)
        }

        let log = ReadableLogRecord(
            resource: .init(),
            instrumentationScopeInfo: .init(),
            timestamp: timestamp,
            severity: Severity.fromLogSeverity(severity),
            body: .string(message),
            attributes: otelAttributes
        )

        logs.append(log)
    }
}
