//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetryApi
import OpenTelemetrySdk
import TestSupport
import XCTest

@testable import EmbraceOTelBridge

/// `EmbraceSpanProcessor` gates all child processor/exporter forwarding behind
/// `criticalResourceGroup`, so children never receive spans before critical SDK resources
/// are ready.
///
/// In `EmbraceIO.start(options:)` that group is `Embrace.client.captureServicesGroup`, which is
/// `enter()`ed in `Embrace.init` and `leave()`d at exactly one place: the success path of
/// `Embrace.start()`. Every early exit from `start()` (the SDK-already-started guard, the
/// `config.isSDKEnabled == false` remote kill-switch, the non-main-thread `throw`, or a host that
/// calls `setup()` and never `start()`) skips that `leave()`, leaving the group permanently
/// pending.
///
/// The child processors and exporters behind this gate are exclusively user-supplied
/// (`OTelOptions.spanProcessor`/`.spanExporter`); Embrace's own storage path runs through the
/// delegate, which is synchronous and ungated. So a group that is never left silently starves a
/// customer's own OpenTelemetry pipeline forever, and blocks `forceFlush`/`shutdown` past the
/// timeouts they were handed.
///
/// These tests pin both halves of the contract: the gate must still defer forwarding while
/// resources are genuinely pending, and it must never block indefinitely.
final class SpanProcessorCriticalGroupTests: XCTestCase {

    /// Every wait here is deliberately far from the value it discriminates against, so load on
    /// the machine cannot flip a verdict.
    ///
    /// - `gate`: what a span pays if the gate is (incorrectly) re-waited.
    /// - `unpaidWait`: budget for a span that should pay nothing. Well under `gate`, well over
    ///   the dispatch hop it actually costs.
    /// - `generousWait`: upper bound for things that should happen, sized to outlast `gate`
    ///   several times over rather than to measure anything.
    private static let gate: DispatchTimeInterval = .seconds(2)
    private static let unpaidWait: TimeInterval = 0.75
    private static let generousWait: TimeInterval = 15.0

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
        exporter: SpanExporter,
        gateTimeout: DispatchTimeInterval
    ) -> (EmbraceSpanProcessor, Tracer) {
        let processor = EmbraceSpanProcessor(delegate: mockDelegate, childExporters: [exporter])
        processor.criticalResourceTimeout = gateTimeout
        processor.criticalResourceGroup = pendingGroup
        let provider = TracerProviderSdk(spanProcessors: [processor])
        return (processor, provider.get(instrumentationName: "test", instrumentationVersion: nil))
    }

    // MARK: - The gate still defers while resources are genuinely pending

    /// The guarantee the group exists for must survive the fix: while critical resources are
    /// still pending and the timeout has not elapsed, children receive nothing.
    func test_pendingGroup_defersForwardingUntilReleased() {
        let exporter = CapturingSpanExporter()
        let (_, tracer) = makeProcessor(exporter: exporter, gateTimeout: .seconds(30))

        tracer.spanBuilder(spanName: "deferred-span").startSpan().end()

        // Assert absence only after giving forwarding a real chance to happen.
        wait(delay: 0.5)
        XCTAssertTrue(
            exporter.exportedSpans.isEmpty,
            "span reached the child exporter while critical resources were still pending"
        )

        leaveGroup()

        wait(timeout: Self.generousWait) { exporter.exportedSpans.contains { $0.name == "deferred-span" } }
    }

    // MARK: - The gate must never block indefinitely

    /// A group that is never left must not starve child exporters forever.
    func test_neverReleasedGroup_forwardsAfterTimeout() {
        let exporter = CapturingSpanExporter()
        let (_, tracer) = makeProcessor(exporter: exporter, gateTimeout: .milliseconds(100))

        tracer.spanBuilder(spanName: "gated-span").startSpan().end()

        // The group is deliberately never left. Polls rather than sampling once, so a loaded
        // machine that exports late does not turn this into a flake.
        wait(timeout: Self.generousWait) { exporter.exportedSpans.contains { $0.name == "gated-span" } }
        XCTAssertTrue(
            exporter.exportedSpans.contains { $0.name == "gated-span" },
            "child exporter never received the span; the critical resource gate blocks indefinitely"
        )
    }

    /// The gate must be paid at most once. A group that is never left times out on *every*
    /// `wait`, so re-waiting would serialize every span behind a fresh full timeout, turning a
    /// permanent hang into a permanent stall.
    func test_neverReleasedGroup_waitsAtMostOnce() {
        let exporter = CapturingSpanExporter()
        let (_, tracer) = makeProcessor(exporter: exporter, gateTimeout: Self.gate)

        tracer.spanBuilder(spanName: "first-span").startSpan().end()
        // Generous: the first span legitimately pays the gate once (Self.gate), and this only
        // needs to outlast that, not to measure it.
        wait(timeout: Self.generousWait) { exporter.exportedSpans.contains { $0.name == "first-span" } }

        // The gate has now timed out once. This is a binary discriminator, not a stopwatch:
        // paying the gate again would cost Self.gate (2s), while not paying it costs a dispatch
        // hop (single-digit ms). Self.unpaidWait (0.75s) sits between the two with room on both
        // sides, so neither a slow machine nor a fast one changes the verdict.
        tracer.spanBuilder(spanName: "second-span").startSpan().end()
        wait(timeout: Self.unpaidWait) { exporter.exportedSpans.contains { $0.name == "second-span" } }

        XCTAssertTrue(
            exporter.exportedSpans.contains { $0.name == "second-span" },
            "second span paid the critical resource timeout again; the gate is re-waited per span"
        )
    }

    /// `forceFlush(timeout:)` must honor the timeout it was handed.
    func test_neverReleasedGroup_forceFlushReturnsWithinItsTimeout() {
        let exporter = CapturingSpanExporter()
        let (processor, tracer) = makeProcessor(exporter: exporter, gateTimeout: .seconds(30))

        // Occupy the serial queue with work parked on the pending group.
        tracer.spanBuilder(spanName: "parked-span").startSpan().end()

        let returned = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            processor.forceFlush(timeout: 0.1)
            returned.signal()
        }

        XCTAssertEqual(
            returned.wait(timeout: .now() + Self.generousWait),
            .success,
            "forceFlush(timeout: 0.1) did not return; the timeout is not honored"
        )

        // Returning early abandons the wait, not the work. Once the gate clears, the flush must
        // still reach the child exporter: a "fix" that dropped the queued work would satisfy the
        // assertion above while silently losing flushes.
        leaveGroup()
        wait(timeout: Self.generousWait) { exporter.didFlush }
    }

    /// `shutdown(explicitTimeout:)` has the same `processorQueue.sync` exposure, so a pending
    /// group must not block SDK teardown either.
    func test_neverReleasedGroup_shutdownReturnsWithinItsTimeout() {
        let exporter = CapturingSpanExporter()
        let (processor, tracer) = makeProcessor(exporter: exporter, gateTimeout: .seconds(30))

        tracer.spanBuilder(spanName: "parked-span").startSpan().end()

        let returned = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            processor.shutdown(explicitTimeout: 0.1)
            returned.signal()
        }

        XCTAssertEqual(
            returned.wait(timeout: .now() + Self.generousWait),
            .success,
            "shutdown(explicitTimeout: 0.1) did not return; the timeout is not honored"
        )

        // As with forceFlush, the abandoned work must still run once the gate clears.
        leaveGroup()
        wait(timeout: Self.generousWait) { exporter.didShutdown }
    }
}
