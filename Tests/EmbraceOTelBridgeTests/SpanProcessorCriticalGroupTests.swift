//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetryApi
import OpenTelemetrySdk
import TestSupport
import XCTest

@testable import EmbraceCommonInternal
@testable import EmbraceOTelBridge
@testable import EmbraceSemantics

/// `EmbraceSpanProcessor` gates all child processor/exporter forwarding behind
/// `criticalResourceGroup?.wait()` — an *unbounded* wait executed on its serial
/// `processorQueue`.
///
/// In `EmbraceIO.start(options:)` that group is `Embrace.client.captureServicesGroup`, which is
/// `enter()`ed in `Embrace.init` and `leave()`d at exactly one place: the success path of
/// `Embrace.start()`. Every early exit from `start()` — the SDK-already-started guard, the
/// `config.isSDKEnabled == false` remote kill-switch, the non-main-thread `throw`, or a host that
/// calls `setup()` and never `start()` — skips that `leave()`, leaving the group permanently
/// pending.
///
/// These tests pin the resulting behavior: the serial queue blocks forever on the first span, so
/// custom exporters silently receive nothing, and `forceFlush`/`shutdown` (which use
/// `processorQueue.sync`) block their caller forever, ignoring the timeout they were handed.
final class EmbraceSpanProcessorCriticalResourceGroupTests: XCTestCase {

    private var mockDelegate: MockSpanProcessorDelegate!
    private var pendingGroup: DispatchGroup!
    private var didLeaveGroup = false

    override func setUp() {
        super.setUp()
        mockDelegate = MockSpanProcessorDelegate()
        pendingGroup = DispatchGroup()
        pendingGroup.enter()
        didLeaveGroup = false
    }

    override func tearDown() {
        // Never leave a blocked serial queue behind for the next test.
        leaveGroup()
        super.tearDown()
    }

    private func leaveGroup() {
        guard !didLeaveGroup else { return }
        didLeaveGroup = true
        pendingGroup.leave()
    }

    private func makeProcessor(
        exporter: SpanExporter
    ) -> (EmbraceSpanProcessor, Tracer) {
        let processor = EmbraceSpanProcessor(delegate: mockDelegate, childExporters: [exporter])
        processor.criticalResourceGroup = pendingGroup
        let provider = TracerProviderSdk(spanProcessors: [processor])
        return (processor, provider.get(instrumentationName: "test", instrumentationVersion: nil))
    }

    // MARK: -

    /// A `criticalResourceGroup` that is never left starves child exporters indefinitely.
    func test_pendingCriticalResourceGroup_starvesChildExporters() {
        let exporter = GatedCapturingSpanExporter()
        let (_, tracer) = makeProcessor(exporter: exporter)

        tracer.spanBuilder(spanName: "starved-span").startSpan().end()

        let exported = XCTestExpectation(description: "child exporter receives span data")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            if exporter.exportedSpans.contains(where: { $0.name == "starved-span" }) {
                exported.fulfill()
            }
        }
        XCTAssertEqual(
            XCTWaiter().wait(for: [exported], timeout: 1.5),
            .timedOut,
            "Span reached the child exporter while the critical resource group was still pending."
        )

        // Positive control: the very same span flows once the group is released, proving the
        // starvation above is the gate and not a wiring mistake in this test.
        leaveGroup()

        let flushed = XCTestExpectation(description: "child exporter drains after group is left")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            if exporter.exportedSpans.contains(where: { $0.name == "starved-span" }) {
                flushed.fulfill()
            }
        }
        XCTAssertEqual(XCTWaiter().wait(for: [flushed], timeout: .defaultTimeout), .completed)
    }

    /// `forceFlush(timeout:)` blocks its caller forever, ignoring the timeout it was given.
    func test_pendingCriticalResourceGroup_blocksForceFlushPastItsTimeout() {
        let exporter = GatedCapturingSpanExporter()
        let (processor, tracer) = makeProcessor(exporter: exporter)

        // Occupy the serial queue with work parked on the pending group.
        tracer.spanBuilder(spanName: "parked-span").startSpan().end()

        let returned = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            processor.forceFlush(timeout: 0.1)
            returned.signal()
        }

        XCTAssertEqual(
            returned.wait(timeout: .now() + 1.5),
            .timedOut,
            "forceFlush(timeout: 0.1) should still be blocked — the timeout is not honored."
        )

        leaveGroup()
        XCTAssertEqual(
            returned.wait(timeout: .now() + .defaultTimeout),
            .success,
            "forceFlush never returned even after the group was released."
        )
    }

    /// `shutdown(explicitTimeout:)` has the same `processorQueue.sync` exposure, so a pending
    /// group blocks SDK teardown too.
    func test_pendingCriticalResourceGroup_blocksShutdownPastItsTimeout() {
        let exporter = GatedCapturingSpanExporter()
        let (processor, tracer) = makeProcessor(exporter: exporter)

        tracer.spanBuilder(spanName: "parked-span").startSpan().end()

        let returned = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            processor.shutdown(explicitTimeout: 0.1)
            returned.signal()
        }

        XCTAssertEqual(
            returned.wait(timeout: .now() + 1.5),
            .timedOut,
            "shutdown(explicitTimeout: 0.1) should still be blocked — the timeout is not honored."
        )

        leaveGroup()
        XCTAssertEqual(
            returned.wait(timeout: .now() + .defaultTimeout),
            .success,
            "shutdown never returned even after the group was released."
        )
    }
}

/// Local to this file so it stays independent of the mocks in `EmbraceSpanProcessorTests`.
private class GatedCapturingSpanExporter: SpanExporter {
    @TestLocked var exportedSpans: [SpanData] = []
    @TestLocked var didFlush = false
    @TestLocked var didShutdown = false

    func export(spans: [SpanData], explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
        exportedSpans.append(contentsOf: spans)
        return .success
    }

    func flush(explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
        didFlush = true
        return .success
    }

    func shutdown(explicitTimeout: TimeInterval?) {
        didShutdown = true
    }
}
