//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceSemantics
import EmbraceStorageInternal
import TestSupport
import XCTest

@testable import EmbraceCore

/// Forwards every call to a real handler, keeping a reference to the spans it creates so a test can
/// inspect the live span. Deliberately a passthrough: the real limiter and sanitizer stay in the path.
private final class SpanCapturingHandler: EmbraceOTelSignalsHandler {

    let wrapped: DefaultOTelSignalsHandler
    private(set) var createdSpans: [EmbraceSpan] = []

    init(wrapping wrapped: DefaultOTelSignalsHandler) {
        self.wrapped = wrapped
    }

    func _createSpan(
        name: String,
        parentSpan: EmbraceSpan?,
        type: EmbraceType,
        status: EmbraceSpanStatus,
        startTime: Date,
        endTime: Date?,
        events: [EmbraceSpanEvent],
        links: [EmbraceSpanLink],
        attributes: EmbraceAttributes,
        autoTerminationCode: EmbraceSpanErrorCode?,
        isInternal: Bool
    ) throws -> EmbraceSpan {
        let span = try wrapped._createSpan(
            name: name,
            parentSpan: parentSpan,
            type: type,
            status: status,
            startTime: startTime,
            endTime: endTime,
            events: events,
            links: links,
            attributes: attributes,
            autoTerminationCode: autoTerminationCode,
            isInternal: isInternal
        )
        createdSpans.append(span)
        return span
    }

    func _addSessionEvent(
        name: String,
        type: EmbraceType?,
        timestamp: Date,
        attributes: EmbraceAttributes,
        isInternal: Bool
    ) throws -> EmbraceSpanEvent? {
        try wrapped._addSessionEvent(
            name: name,
            type: type,
            timestamp: timestamp,
            attributes: attributes,
            isInternal: isInternal
        )
    }

    func _log(
        _ message: String,
        severity: EmbraceLogSeverity,
        type: EmbraceType,
        timestamp: Date,
        attachment: EmbraceLogAttachment?,
        attributes: EmbraceAttributes,
        stackTraceBehavior: EmbraceStackTraceBehavior,
        isInternal: Bool,
        send: Bool
    ) throws {
        try wrapped._log(
            message,
            severity: severity,
            type: type,
            timestamp: timestamp,
            attachment: attachment,
            attributes: attributes,
            stackTraceBehavior: stackTraceBehavior,
            isInternal: isInternal,
            send: send
        )
    }
}

/// Drives `StateRecorder` through the **real** OTel handler, limiter and sanitizer rather than
/// `MockOTelSignalsHandler`, which applies no limits at all.
///
/// State spans are created with `createInternalSpan`, so they are `InternalEmbraceSpan`s, whose
/// `addEvent`/`setAttribute` overrides take the `isInternal: true` path and bypass the customer-facing
/// event-count, attribute-count and sanitization limits. These tests pin that: without them, a
/// well-meaning change routing transitions through the public span API would silently cap the
/// per-part transition budget at `SessionLimits.SpanEventLimits.customSpanEventCount` and start
/// over-reporting `emb.state.transition_count`.
final class StateRecorderLimitsTests: XCTestCase {

    private var capturing: SpanCapturingHandler!
    private var handler: DefaultOTelSignalsHandler!
    private var sessionController: MockSessionController!
    private var logController: LogController!
    private var storage: EmbraceStorage!
    private var upload: SpyEmbraceLogUploader!

    /// The customer-facing per-span event cap. Transitions must NOT be subject to it.
    private let customEventLimit = Int(SessionLimits().events.customSpanEventCount)

    override func setUpWithError() throws {
        storage = try EmbraceStorage.createInMemoryDb()
        upload = SpyEmbraceLogUploader()

        sessionController = MockSessionController()
        sessionController.storage = storage

        logController = LogController(
            storage: storage,
            upload: upload,
            sessionController: sessionController,
            queue: .main
        )

        // The real limiter and the real sanitizer — the whole point of this suite.
        handler = DefaultOTelSignalsHandler(
            storage: storage,
            sessionController: sessionController,
            logController: logController,
            limiter: DefaultOtelSignalsLimiter(),
            sanitizer: DefaultOtelSignalsSanitizer()
        )

        sessionController.spanHandler = handler
        sessionController.startSession(state: .foreground)

        capturing = SpanCapturingHandler(wrapping: handler)
    }

    override func tearDownWithError() throws {
        capturing = nil
        handler = nil
        sessionController = nil
        logController = nil
        upload = nil
        storage = nil
    }

    private func makeRecorder(maxTransitions: Int) throws -> (StateRecorder<String>, EmbraceSpan) {
        let sessionSpan = try XCTUnwrap(sessionController.currentSessionSpan)
        let recorder = StateRecorder<String>(
            stateName: "limits-test",
            defaultValue: "initial",
            otel: capturing,
            maxTransitions: maxTransitions
        )
        recorder.onSessionPartStart(sessionSpan: sessionSpan, at: Date())
        recorder.activate(at: Date())
        return (recorder, sessionSpan)
    }

    func testTransitionsAreNotSubjectToTheCustomerFacingEventLimit() throws {
        // Given a budget well above the customer-facing event cap
        let target = customEventLimit * 3
        let (recorder, _) = try makeRecorder(maxTransitions: target + 100)

        let span = try XCTUnwrap(
            capturing.createdSpans.first { $0.name == SpanSemantics.State.spanName(for: "limits-test") }
        )

        // When we record more transitions than the custom-span event limit allows
        for i in 0..<target {
            recorder.onStateChange(to: "screen-\(i)", at: Date())
        }

        // Then every one of them became an event...
        XCTAssertEqual(
            span.events.filter { $0.name == SpanSemantics.State.transitionEventName }.count,
            target,
            "state transitions must bypass the \(customEventLimit)-event customer limit")

        // ...and the count written at close agrees with the events actually present, which is the
        // wire-contract invariant that would break if transitions were silently dropped.
        recorder.onSessionPartWillEnd(at: Date())
        XCTAssertEqual(
            span.attributes[SpanSemantics.State.keyTransitionCount]?.description,
            String(target))
    }

    func testMaxTransitionsIsTheOnlyBindingCap() throws {
        // Given a cap deliberately set above the customer event limit
        let cap = customEventLimit + 5
        let (recorder, _) = try makeRecorder(maxTransitions: cap)

        let span = try XCTUnwrap(
            capturing.createdSpans.first { $0.name == SpanSemantics.State.spanName(for: "limits-test") }
        )

        // When we exceed it
        for i in 0..<(cap + 10) {
            recorder.onStateChange(to: "screen-\(i)", at: Date())
        }

        // Then the recorder's own cap is what bit — not the OTel event limit
        XCTAssertEqual(
            span.events.filter { $0.name == SpanSemantics.State.transitionEventName }.count,
            cap)

        // ...and the overflow was counted rather than lost.
        recorder.onSessionPartWillEnd(at: Date())
        XCTAssertEqual(
            span.attributes[SpanSemantics.State.keyTransitionCount]?.description,
            String(cap))
        XCTAssertEqual(
            span.attributes[SpanSemantics.State.keyDroppedByInstrumentation]?.description,
            "10")
    }

    func testTheStateLinkSurvivesASessionThatExhaustedTheCustomerLinkBudget() throws {
        // Given a session part span carrying plenty of customer events — breadcrumbs, in production.
        let sessionSpan = try XCTUnwrap(sessionController.currentSessionSpan)
        let customerEvents = Int(SessionLimits().links.customSpanLinkCount) * 2
        for i in 0..<customerEvents {
            sessionSpan.addEvent(name: "breadcrumb-\(i)", type: nil, timestamp: Date(), attributes: [:])
        }

        // ...and a customer link budget that is fully spent.
        for i in 0..<customerEvents {
            sessionSpan.addLink(spanId: .randomSpanId(), traceId: .randomTraceId(), attributes: ["i": "\(i)"])
        }

        let recorder = StateRecorder<String>(
            stateName: "limits-test",
            defaultValue: "initial",
            otel: capturing
        )
        recorder.onSessionPartStart(sessionSpan: sessionSpan, at: Date())
        recorder.activate(at: Date())

        let stateSpan = try XCTUnwrap(
            capturing.createdSpans.first { $0.name == SpanSemantics.State.spanName(for: "limits-test") }
        )

        // When the part ends
        recorder.onSessionPartWillEnd(at: Date())

        // Then the SDK's own structural link is still there, because it does not compete with
        // customer telemetry for the per-span budget.
        let stateLinks = sessionSpan.links.filter {
            $0.attributes[SpanSemantics.keyLinkType]?.description == SpanSemantics.State.linkType
        }
        XCTAssertEqual(stateLinks.count, 1, "the STATE link must survive a busy session")
        XCTAssertEqual(stateLinks.first?.context.spanId, stateSpan.context.spanId)
    }

    func testNewValueSurvivesAlongsideManyCallerAttributes() throws {
        // Given more caller attributes than the customer-facing per-event attribute cap
        let (recorder, _) = try makeRecorder(maxTransitions: 100)

        let span = try XCTUnwrap(
            capturing.createdSpans.first { $0.name == SpanSemantics.State.spanName(for: "limits-test") }
        )

        // Keys chosen to sort BEFORE "emb.state.new_value" alphabetically, which is the order the
        // sanitizer truncates in — so if transitions were sanitized, these would evict the one
        // attribute the contract says is always present.
        var attributes: EmbraceAttributes = [:]
        for i in 0..<20 {
            attributes["aaa-key-\(i)"] = "value-\(i)"
        }

        // When a transition carries them
        recorder.onStateChange(to: "ProductDetail", at: Date(), attributes: attributes)

        // Then the mandatory attribute is still there
        let event = try XCTUnwrap(span.events.first { $0.name == SpanSemantics.State.transitionEventName })
        XCTAssertEqual(
            event.attributes[SpanSemantics.State.keyNewValue]?.description,
            "ProductDetail",
            "emb.state.new_value must never be evicted by caller attributes")
    }
}
