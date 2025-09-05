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

    public func createSpan(
        name: String,
        parentSpan: EmbraceSpan?,
        type: EmbraceType,
        status: EmbraceSpanStatus,
        startTime: Date,
        endTime: Date?,
        events: [EmbraceSpanEvent],
        links: [EmbraceSpanLink],
        attributes: [String: String],
        autoTerminationCode: EmbraceSpanErrorCode?
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

    public func addSessionEvent(
        name: String,
        type: EmbraceType?,
        timestamp: Date,
        attributes: [String: String]
    ) throws {
        let event = EmbraceSpanEvent(
            name: name,
            type: type,
            timestamp: timestamp,
            attributes: attributes
        )
        events.append(event)
    }

    public func log(
        _ message: String,
        severity: EmbraceLogSeverity,
        type: EmbraceType,
        timestamp: Date,
        attachment: EmbraceLogAttachment?,
        attributes: [String: String],
        stackTraceBehavior: EmbraceStackTraceBehavior
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
        attributes: [String: String]
    ) {
        log(
            message,
            severity: severity,
            type: type,
            timestamp: timestamp,
            attachment: nil,
            attributes: attributes,
            stackTraceBehavior: .notIncluded()
        )
    }
}
