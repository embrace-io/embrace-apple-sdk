//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
    import EmbraceCommonInternal
#endif

/// OTel `SpanProcessor` that intercepts spans from any OTel tracer using the shared provider.
///
/// Spans that were created by `EmbraceOTelBridge` itself (outbound signals) are identified
/// via `EmbraceSpanProcessorDelegate.isInternalSpan` and skipped — only genuinely external
/// spans are forwarded to `EmbraceCore` via the delegate.
///
/// All spans (internal and external) are forwarded to the child processors and exporters
/// supplied at init time, making this processor the single root of the span pipeline.
///
/// Attribute injection and delegate notifications happen synchronously on the calling thread;
/// child processor/exporter forwarding is dispatched to a dedicated utility queue so the
/// OTel calling thread is not blocked. Before the first forwarding runs, that queue waits on
/// `criticalResourceGroup` (set by the bridge after `Embrace.setup` completes) so children do
/// not receive spans while critical SDK resources are still coming up.
///
/// That wait is best effort rather than a guarantee: it is bounded by `criticalResourceTimeout`
/// and paid at most once. Only the success path of `Embrace.start()` and its remote kill-switch
/// guard ever satisfy the group, so a host that calls `setup()` without `start()`, or whose
/// `start()` throws, would otherwise park the pipeline forever. Once the wait ends, whether by
/// release or by timeout, every later span forwards without gating.
class EmbraceSpanProcessor: SpanProcessor {

    var isStartRequired: Bool { true }
    var isEndRequired: Bool { true }

    weak var delegate: EmbraceSpanProcessorDelegate?

    /// Set by `EmbraceOTelBridge.setup(delegate:metadataProvider:criticalResourceGroup:)`
    /// after `Embrace.setup()` completes. Child forwarding waits on this group before proceeding.
    var criticalResourceGroup: DispatchGroup?

    /// Upper bound on how long child forwarding waits for `criticalResourceGroup`.
    var criticalResourceTimeout: DispatchTimeInterval = .seconds(10)

    private let childProcessors: [SpanProcessor]
    private let childExporters: [SpanExporter]
    private let processorQueue = DispatchQueue(label: "io.embrace.otelbridge.spanprocessor", qos: .utility)
    private let didWaitForCriticalResources = EmbraceMutex(false)

    init(
        delegate: EmbraceSpanProcessorDelegate? = nil,
        childProcessors: [SpanProcessor] = [],
        childExporters: [SpanExporter] = []
    ) {
        self.delegate = delegate
        self.childProcessors = childProcessors
        self.childExporters = childExporters
    }

    func onStart(parentContext: SpanContext?, span: any ReadableSpan) {
        if let delegate, !delegate.isInternalSpan(span) {
            injectAttributes(span, delegate: delegate)
            delegate.onExternalSpanStarted(span)
        }

        let mkSpan = EmbraceMetricKitSpan.begin(name: "span-processor-onstart")
        processorQueue.async { [self] in
            waitForCriticalResources()
            for processor in childProcessors {
                processor.onStart(parentContext: parentContext, span: span)
            }
            mkSpan.end()
        }
    }

    func onEnd(span: any ReadableSpan) {
        if let delegate, !delegate.isInternalSpan(span) {
            delegate.onExternalSpanEnded(span)
        }

        let mkProcessSpan = EmbraceMetricKitSpan.begin(name: "span-processor-onend")
        processorQueue.async { [self] in
            waitForCriticalResources()
            for var processor in childProcessors {
                processor.onEnd(span: span)
            }
            mkProcessSpan.end()

            let mkExportSpan = EmbraceMetricKitSpan.begin(name: "span-exporter-onend")
            let spanData = span.toSpanData()
            for exporter in childExporters {
                _ = exporter.export(spans: [spanData])
            }
            mkExportSpan.end()
        }
    }

    func forceFlush(timeout: TimeInterval?) {
        let mkProcessSpan = EmbraceMetricKitSpan.begin(name: "span-processor-forceflush")
        runOnQueue(timeout: timeout) { [self] in
            for processor in childProcessors {
                processor.forceFlush(timeout: timeout)
            }
            mkProcessSpan.end()

            let mkExportSpan = EmbraceMetricKitSpan.begin(name: "span-exporter-forceflush")
            for exporter in childExporters {
                _ = exporter.flush(explicitTimeout: timeout)
            }
            mkExportSpan.end()
        }
    }

    /// Drains the internal processor queue synchronously by enqueuing an empty barrier and
    /// waiting. Used by benchmark/test harnesses to ensure all queued span work is processed
    /// before measurements are taken.
    func waitForAllWork() {
        let group = DispatchGroup()
        processorQueue.async(group: group, flags: .assignCurrentContext) {}
        group.wait()
    }

    func shutdown(explicitTimeout: TimeInterval?) {
        runOnQueue(timeout: explicitTimeout) { [self] in
            for var processor in childProcessors {
                processor.shutdown(explicitTimeout: explicitTimeout)
            }
            for exporter in childExporters {
                exporter.shutdown(explicitTimeout: explicitTimeout)
            }
        }
    }

    // MARK: - Private

    /// Waits for critical SDK resources, bounded by `criticalResourceTimeout`.
    ///
    /// The bound matters because `captureServicesGroup` is `leave()`d only on the success path
    /// of `Embrace.start()`. Every early exit, and a host that calls `setup()` without
    /// `start()`, leaves it pending forever. An unbounded wait there silently starves the
    /// user-supplied exporters behind this gate rather than merely delaying them.
    private func waitForCriticalResources() {
        guard let criticalResourceGroup else { return }

        // Pay the gate at most once. A group that is never left times out on *every* wait, so
        // re-waiting would charge each span a fresh full timeout and stall the pipeline
        // permanently rather than merely delaying its first span. Claiming the wait in a single
        // locked step makes that "at most once" a property of this flag rather than of the
        // serial queue the callers happen to share.
        let shouldWait = didWaitForCriticalResources.withLock { didWait -> Bool in
            guard !didWait else { return false }
            didWait = true
            return true
        }
        guard shouldWait else { return }

        _ = criticalResourceGroup.wait(timeout: .now() + criticalResourceTimeout)
    }

    /// Runs `work` on `processorQueue`, returning once it completes or `timeout` elapses,
    /// whichever is first.
    ///
    /// `processorQueue` is serial and may already be occupied by forwarding parked on the
    /// critical resource gate, so a plain `sync` would make the caller wait for that work
    /// regardless of the timeout it passed in.
    ///
    /// A timeout abandons the wait, not the work: `work` stays queued and runs to completion
    /// afterwards. Returning is therefore not proof the work is done. For `shutdown` that means
    /// children can be shut down after the SDK considers teardown finished, which is the
    /// deliberate trade for not hanging teardown behind a gate that was never released.
    private func runOnQueue(timeout: TimeInterval?, _ work: @escaping () -> Void) {
        let finished = DispatchSemaphore(value: 0)
        processorQueue.async {
            work()
            finished.signal()
        }
        if let timeout {
            _ = finished.wait(timeout: .now() + timeout)
        } else {
            finished.wait()
        }
    }

    /// Stamps external spans with required Embrace attributes before they reach child processors
    /// or the `EmbraceCore` delegate.
    ///
    /// Identity is stamped as three keys, always present (empty strings when unknown) so the
    /// backend can correlate every signal back to a user session/part — `session.id` carries
    /// the user-session UUID in v7, `emb.user_session_id` mirrors it, and `emb.session_part_id`
    /// carries the part UUID (the value `session.id` had pre-v7).
    private func injectAttributes(_ span: ReadableSpan, delegate: EmbraceSpanProcessorDelegate) {
        span.setAttribute(key: SpanSemantics.keyEmbraceType, value: .string(EmbraceType.performance.rawValue))
        span.setAttribute(key: SpanSemantics.Session.keyState, value: .string(delegate.currentSessionState.rawValue))

        let userSessionId = delegate.currentUserSessionId?.stringValue ?? ""
        let partId = delegate.currentSessionId?.stringValue ?? ""
        span.setAttribute(key: SpanSemantics.keySessionId, value: .string(userSessionId))
        span.setAttribute(key: SpanSemantics.Session.keyUserSessionId, value: .string(userSessionId))
        span.setAttribute(key: SpanSemantics.Session.keyPartId, value: .string(partId))
    }
}
