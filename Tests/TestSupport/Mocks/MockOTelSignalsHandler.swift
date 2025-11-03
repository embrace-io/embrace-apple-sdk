//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceSemantics
import Foundation

@testable import EmbraceCore

public class MockOTelSignalsHandler: InternalOTelSignalsHandler, MockSpanDelegate {

    private(set) public var startedSpans: [EmbraceSpan] = []
    private(set) public var endedSpans: [EmbraceSpan] = []
    private(set) public var events: [EmbraceSpanEvent] = []
    private(set) public var logs: [EmbraceLog] = []

    public var currentSessionId: EmbraceIdentifier? = .random
    public var currentProcessId: EmbraceIdentifier = .random

    public init() {}

    public func _createSpan(
        name: String,
        parentSpan: EmbraceSpan? = nil,
        type: EmbraceType,
        status: EmbraceSpanStatus = .unset,
        startTime: Date,
        endTime: Date? = nil,
        events: [EmbraceSpanEvent] = [],
        links: [EmbraceSpanLink] = [],
        attributes: EmbraceAttributes = [:],
        autoTerminationCode: EmbraceSpanErrorCode? = nil,
        isInternal: Bool = true
    ) throws -> EmbraceSpan {

        let traceId = parentSpan?.context.traceId ?? .randomTraceId()

        let span = MockSpan(
            id: .randomSpanId(),
            traceId: traceId,
            parentSpanId: parentSpan?.context.spanId,
            name: name,
            type: type,
            status: status,
            startTime: startTime,
            endTime: endTime,
            events: events,
            links: links,
            sessionId: currentSessionId,
            processId: currentProcessId,
            attributes: attributes,
            delegate: self
        )

        startedSpans.append(span)

        if endTime != nil {
            endedSpans.append(span)
        }

        return span
    }

    public func _addSessionEvent(
        name: String,
        type: EmbraceType? = nil,
        timestamp: Date = Date(),
        attributes: EmbraceAttributes = [:],
        isInternal: Bool = true
    ) throws {
        let event = EmbraceSpanEvent(
            name: name,
            type: type,
            timestamp: timestamp,
            attributes: attributes
        )
        events.append(event)
    }

    public func _log(
        _ message: String,
        severity: EmbraceLogSeverity = .info,
        type: EmbraceType,
        timestamp: Date = Date(),
        attachment: EmbraceLogAttachment? = nil,
        attributes: EmbraceAttributes = [:],
        stackTraceBehavior: EmbraceStackTraceBehavior = .default,
        isInternal: Bool = true,
        send: Bool = true
    ) {
        let log = MockLog(
            id: UUID().withoutHyphen,
            severity: severity,
            type: type,
            timestamp: timestamp,
            body: message,
            attributes: attributes,
            sessionId: currentSessionId,
            processId: currentProcessId
        )

        logs.append(log)
    }

    public func onSpanEnded(_ span: EmbraceSpan) {
        endedSpans.append(span)
    }

    public func autoTerminateSpans() {

    }

    public func exportLog(
        _ message: String,
        severity: EmbraceLogSeverity,
        type: EmbraceType,
        timestamp: Date,
        attributes: EmbraceAttributes
    ) {
        _log(
            message,
            severity: severity,
            type: type,
            timestamp: timestamp,
            attachment: nil,
            attributes: attributes,
            stackTraceBehavior: .notIncluded
        )
    }
}
