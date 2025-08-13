//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceSemantics
import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

@testable import EmbraceCore
@testable import EmbraceOTelInternal

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
        type: EmbraceType,
        attributes: [String: String] = [:],
        autoTerminationCode: SpanErrorCode? = nil
    ) -> SpanBuilder {
        return EmbraceOTel()
            .buildSpan(name: name, type: type, attributes: attributes)
    }

    public func recordCompletedSpan(
        name: String,
        type: EmbraceType,
        parent: Span?,
        startTime: Date,
        endTime: Date,
        attributes: [String: String],
        events: [RecordingSpanEvent],
        errorCode: SpanErrorCode?
    ) {
        let builder = EmbraceOTel().buildSpan(name: name, type: type, attributes: attributes)
        builder.setStartTime(time: startTime)

        if let parent = parent {
            builder.setParent(parent)
        }

        let span = builder.startSpan()
        span.end(time: endTime)
    }

    public func add(events: [SpanEvent]) {
        self.events.append(contentsOf: events)
    }

    public func add(event: SpanEvent) {
        events.append(event)
    }

    public func log(
        _ message: String,
        severity: EmbraceLogSeverity,
        type: EmbraceType = .message,
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
        severity: EmbraceLogSeverity,
        type: EmbraceType = .message,
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

    public func log(
        _ message: String,
        severity: EmbraceLogSeverity,
        type: EmbraceType = .performance,
        timestamp: Date = Date(),
        attachment: Data,
        attributes: [String: String] = [:],
        stackTraceBehavior: StackTraceBehavior = .default
    ) {

    }

    public func log(
        _ message: String,
        severity: EmbraceLogSeverity,
        type: EmbraceType = .performance,
        timestamp: Date = Date(),
        attachmentId: String,
        attachmentUrl: URL,
        attributes: [String: String] = [:],
        stackTraceBehavior: StackTraceBehavior = .default
    ) {

    }
}
