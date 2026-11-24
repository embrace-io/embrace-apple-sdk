//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceSemantics
import Foundation

@testable import EmbraceCore

// `open` so test targets can subclass it. Use `beforeCreateSpan` to interfere with span creation — the window in
// which the SDK holds no lock, and therefore where the races worth testing live.
open class MockOTelSignalsHandler: InternalOTelSignalsHandler, MockSpanDelegate {

    // Appended from background queues (e.g. span delegate callbacks dispatched off the SUT's queues)
    // while tests read them on the main thread — see `TestLocked`.
    @TestLocked public private(set) var startedSpans: [EmbraceSpan] = []
    @TestLocked public private(set) var endedSpans: [EmbraceSpan] = []
    @TestLocked public private(set) var events: [EmbraceSpanEvent] = []
    @TestLocked public private(set) var logs: [EmbraceLog] = []

    /// Sources passed when creating spans, session events and logs, in the order they arrived.
    @TestLocked package private(set) var spanSources: [EmbraceOTelSignalSource] = []
    @TestLocked package private(set) var eventSources: [EmbraceOTelSignalSource] = []
    @TestLocked package private(set) var logSources: [EmbraceOTelSignalSource] = []

    /// Called synchronously when a span is created, like a span processor's `onStart`.
    @TestLocked public var onSpanStartedCallback: ((EmbraceSpan) -> Void)?
    /// Called synchronously when a span ends, like a span processor's `onEnd`.
    @TestLocked public var onSpanEndedCallback: ((EmbraceSpan) -> Void)?

    /// Called synchronously at the start of `_createSpan`. Throwing makes the span creation fail.
    @TestLocked public var beforeCreateSpan: (() throws -> Void)?

    public var currentSessionId: EmbraceIdentifier? = .random
    public var currentProcessId: EmbraceIdentifier = .random

    public init() {}

    package func _createSpan(
        name: String,
        parentContext: EmbraceSpanContext? = nil,
        type: EmbraceType,
        status: EmbraceSpanStatus = .unset,
        startTime: Date,
        endTime: Date? = nil,
        events: [EmbraceSpanEvent] = [],
        links: [EmbraceSpanLink] = [],
        attributes: EmbraceAttributes = [:],
        autoTerminationCode: EmbraceSpanErrorCode? = nil,
        source: EmbraceOTelSignalSource = .sdk
    ) throws -> EmbraceSpan {
        try beforeCreateSpan?()

        spanSources.append(source)

        let traceId = parentContext?.traceId ?? .randomTraceId()

        let span = MockSpan(
            id: .randomSpanId(),
            traceId: traceId,
            parentSpanId: parentContext?.spanId,
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

        onSpanStartedCallback?(span)

        startedSpans.append(span)
        if endTime != nil {
            endedSpans.append(span)
        }

        return span
    }

    @discardableResult
    package func _addSessionEvent(
        name: String,
        type: EmbraceType? = nil,
        timestamp: Date = Date(),
        attributes: EmbraceAttributes = [:],
        source: EmbraceOTelSignalSource = .sdk
    ) throws -> EmbraceSpanEvent? {
        eventSources.append(source)

        let event = EmbraceSpanEvent(
            name: name,
            type: type,
            timestamp: timestamp,
            attributes: attributes
        )
        events.append(event)
        return event
    }

    package func _log(
        _ message: String,
        severity: EmbraceLogSeverity = .info,
        type: EmbraceType,
        timestamp: Date = Date(),
        attachment: EmbraceLogAttachment? = nil,
        attributes: EmbraceAttributes = [:],
        stackTraceBehavior: EmbraceStackTraceBehavior = .default,
        source: EmbraceOTelSignalSource = .sdk
    ) {
        logSources.append(source)

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
        onSpanEndedCallback?(span)

        endedSpans.append(span)
    }

    public func autoTerminateSpans() {

    }

    public func exportLog(_ log: EmbraceLog) {
        logs.append(log)
    }
}
