//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceSemantics
import OpenTelemetryApi
import OpenTelemetrySdk
import TestSupport
import XCTest

@testable import EmbraceOTelBridge

/// Regression test for https://github.com/embrace-io/embrace-apple-sdk/issues/710:
/// "Completed session spans are not exported to custom exporters".
///
/// In 6.x, `EmbraceOTelInternal`'s `EmbraceSpanProcessor.hydrateSpan` returned `nil` for any
/// ended `ux.session` span, so a custom `SpanExporter` (wired via `OpenTelemetryExport`) only
/// ever saw in-progress heartbeat snapshots and never the final, ended span. That processor was
/// removed in 7.0 (#675); today's `EmbraceOTelBridge/EmbraceSpanProcessor` forwards every span
/// to its child exporters on `onEnd`, with no session-span filter.
///
/// This locks that behaviour in at the bridge layer, covering the gap between
/// `EmbraceSpanProcessorTests.test_onEnd_skipsInternalSpans` (an internal span is withheld from
/// the *Core delegate*) and `test_onEnd_forwardsSpanDataToChildExporters` (an *external* span
/// reaches child exporters). Neither asserts what #710 is actually about: an internal span must
/// be withheld from the delegate **and** still reach a user-supplied exporter.
///
/// Scope: this drives `EmbraceOTelBridge` directly, mirroring the three calls `SessionController`
/// ends up making, because `EmbraceOTelBridgeTests` cannot depend on `EmbraceCore`:
/// - `SessionSpanUtils.span(otel:id:startTime:state:coldStart:)` reaches `startSpan` via
///   `DefaultOTelSignalsHandler.createInternalSpan`.
/// - `SessionController.update(heartbeat:)` reaches `updateSpanAttribute` via
///   `SessionSpanUtils.setHeartbeat` → `EmbraceSpan.setInternalAttribute`.
/// - `SessionController.endSessionNoLock` reaches `endSpan` via `EmbraceSpan.end(endTime:)`.
///
/// It therefore does **not** cover the Core-side layers above the bridge (the signals handler,
/// its sanitizer, or `SessionController` itself); a regression introduced there would need a
/// companion test in `EmbraceCoreTests`.
final class SessionSpanCustomExporterTests: XCTestCase {

    // Held as properties: `EmbraceOTelBridge.delegate` and `.metadataProvider` are `weak`, so
    // mocks passed as temporaries would deallocate before the test body runs — leaving the
    // processor on its `delegate == nil` path, where `isInternalSpan` is never consulted and
    // this test would silently stop covering what it claims to.
    private var bridge: EmbraceOTelBridge!
    private var customExporter: InMemorySpanExporter!
    private var mockDelegate: MockOTelDelegate!
    private var mockMetadata: MockMetadataProvider!

    override func setUp() {
        super.setUp()
        customExporter = InMemorySpanExporter()
        mockDelegate = MockOTelDelegate()
        mockMetadata = MockMetadataProvider()
        bridge = EmbraceOTelBridge(spanExporters: [customExporter])
        bridge.setup(delegate: mockDelegate, metadataProvider: mockMetadata)
    }

    func test_endedSessionSpan_isExportedToCustomExporter() throws {
        XCTAssertNotNil(bridge.delegate, "delegate must outlive setup — see the property comment above")
        XCTAssertNotNil(bridge.metadataProvider, "metadata provider must outlive setup")

        let start = Date(timeIntervalSince1970: 1_000)
        let heartbeat = start.addingTimeInterval(30)
        let end = start.addingTimeInterval(60)

        // Mirrors SessionSpanUtils.span(otel:id:startTime:state:coldStart:). `emb.type` is set
        // explicitly here because createInternalSpan stamps it from its `type:` argument.
        let context = bridge.startSpan(
            name: SpanSemantics.Session.name,
            parentSpan: nil,
            status: .unset,
            startTime: start,
            endTime: nil,
            events: [],
            links: [],
            attributes: [
                SpanSemantics.keyEmbraceType: EmbraceType.session.rawValue,
                SpanSemantics.Session.keyPartId: "part-123",
                SpanSemantics.Session.keyState: SessionState.foreground.rawValue,
                SpanSemantics.Session.keyColdStart: String(true)
            ]
        )
        let spanId = try XCTUnwrap(SpanId(fromHexString: context.spanId))
        let sessionSpan = MockEmbraceSpan(spanId: context.spanId, traceId: context.traceId)

        // Mirrors SessionController.update(heartbeat:) -> SessionSpanUtils.setHeartbeat, the
        // periodic tick the original issue described as leaking a partial export every ~5s.
        bridge.updateSpanAttribute(
            sessionSpan,
            key: SpanSemantics.Session.keyHeartbeat,
            value: String(heartbeat.nanosecondsSince1970Truncated)
        )

        // Drain the processor queue before asserting absence: exports are dispatched
        // asynchronously, so an unsynchronized check here could never fail.
        bridge.waitForAllWork()
        XCTAssertEqual(
            customExporter.exportCallCount,
            0,
            "a heartbeat attribute update must not trigger exporter calls"
        )
        XCTAssertTrue(
            customExporter.exportedSpans.isEmpty,
            "no partial snapshot may reach the exporter mid-session"
        )

        // Mirrors SessionController.endSessionNoLock's `inProgressSessionSpan.end(endTime: now)`,
        // which routes through DefaultOTelSignalsHandler.onSpanEnded -> bridge.endSpan.
        bridge.endSpan(sessionSpan, endTime: end)

        // endSpan queues exporter work onto the processor queue; drain deterministically before asserts.
        bridge.waitForAllWork()

        XCTAssertEqual(
            customExporter.exportCallCount,
            1,
            "session span should be exported exactly once, on end"
        )

        let exported = try XCTUnwrap(customExporter.exportedSpans[spanId])

        XCTAssertEqual(exported.name, SpanSemantics.Session.name)
        XCTAssertTrue(exported.hasEnded, "custom exporter must receive the ended span, not an in-progress snapshot")
        XCTAssertEqual(exported.endTime, end)
        XCTAssertEqual(
            exported.attributes[SpanSemantics.keyEmbraceType],
            .string(EmbraceType.session.rawValue),
            "emb.type must survive as ux.session — injectAttributes overwrites it if the span is misread as external"
        )
        XCTAssertEqual(
            exported.attributes[SpanSemantics.Session.keyHeartbeat],
            .string(String(heartbeat.nanosecondsSince1970Truncated)),
            "the final export should still carry the last heartbeat value set during the session"
        )

        // The other half of #710: the span is the bridge's own, so Core must not be notified of
        // it as an external signal — yet it still has to reach the user-supplied exporter above.
        XCTAssertTrue(mockDelegate.startedSpans.isEmpty, "an internal session span must not reach the Core delegate")
        XCTAssertTrue(mockDelegate.endedSpans.isEmpty, "an internal session span must not reach the Core delegate")
    }
}
