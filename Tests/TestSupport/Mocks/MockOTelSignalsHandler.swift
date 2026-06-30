//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceSemantics
import Foundation

@testable import EmbraceCore

public class MockOTelSignalsHandler: InternalOTelSignalsHandler, MockSpanDelegate {

    // These collections are appended from background queues (e.g. span delegate callbacks dispatched
    // off the SUT's queues) while tests read them on the main thread, so guard them with a lock.
    private let lock = NSLock()

    private var _startedSpans: [EmbraceSpan] = []
    public var startedSpans: [EmbraceSpan] {
        lock.lock()
        defer { lock.unlock() }
        return _startedSpans
    }

    private var _endedSpans: [EmbraceSpan] = []
    public var endedSpans: [EmbraceSpan] {
        lock.lock()
        defer { lock.unlock() }
        return _endedSpans
    }

    private var _events: [EmbraceSpanEvent] = []
    public var events: [EmbraceSpanEvent] {
        lock.lock()
        defer { lock.unlock() }
        return _events
    }

    private var _logs: [EmbraceLog] = []
    public var logs: [EmbraceLog] {
        lock.lock()
        defer { lock.unlock() }
        return _logs
    }

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

        lock.lock()
        _startedSpans.append(span)
        if endTime != nil {
            _endedSpans.append(span)
        }
        lock.unlock()

        return span
    }

    @discardableResult
    public func _addSessionEvent(
        name: String,
        type: EmbraceType? = nil,
        timestamp: Date = Date(),
        attributes: EmbraceAttributes = [:],
        isInternal: Bool = true
    ) throws -> EmbraceSpanEvent? {
        let event = EmbraceSpanEvent(
            name: name,
            type: type,
            timestamp: timestamp,
            attributes: attributes
        )
        lock.lock()
        _events.append(event)
        lock.unlock()
        return event
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

        lock.lock()
        _logs.append(log)
        lock.unlock()
    }

    public func onSpanEnded(_ span: EmbraceSpan) {
        lock.lock()
        defer { lock.unlock() }
        _endedSpans.append(span)
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
