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
/// OTel calling thread is not blocked. `criticalResourceGroup` (set by the bridge after
/// `Embrace.setup` completes) is waited on before any child forwarding begins, ensuring
/// children never receive spans before critical SDK resources are ready.
class EmbraceSpanProcessor: SpanProcessor {

    var isStartRequired: Bool { true }
    var isEndRequired: Bool { true }

    weak var delegate: EmbraceSpanProcessorDelegate?

    /// Set by `EmbraceOTelBridge.setup(delegate:metadataProvider:criticalResourceGroup:)`
    /// after `Embrace.setup()` completes. Child forwarding waits on this group before proceeding.
    var criticalResourceGroup: DispatchGroup?

    private let childProcessors: [SpanProcessor]
    private let childExporters: [SpanExporter]
    private let processorQueue = DispatchQueue(label: "io.embrace.otelbridge.spanprocessor", qos: .utility)
    private let processorQueueKey = DispatchSpecificKey<Void>()

    /// Maximum time `forceFlush` and `shutdown` block their caller when no timeout is given.
    static let defaultBlockingTimeout: TimeInterval = 1

    init(
        delegate: EmbraceSpanProcessorDelegate? = nil,
        childProcessors: [SpanProcessor] = [],
        childExporters: [SpanExporter] = []
    ) {
        self.delegate = delegate
        self.childProcessors = childProcessors
        self.childExporters = childExporters

        processorQueue.setSpecific(key: processorQueueKey, value: ())
    }

    func onStart(parentContext: SpanContext?, span: any ReadableSpan) {
        if let delegate, !delegate.isInternalSpan(span) {
            injectAttributes(span, delegate: delegate)
            delegate.onExternalSpanStarted(span)
        }

        let mkSpan = EmbraceMetricKitSpan.begin(name: "span-processor-onstart")
        processorQueue.async { [self] in
            criticalResourceGroup?.wait()
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
            criticalResourceGroup?.wait()
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
        let mkExportSpan = EmbraceMetricKitSpan.begin(name: "span-exporter-forceflush")
        performAndWait(timeout: timeout) { [self] in
            for processor in childProcessors {
                processor.forceFlush(timeout: timeout)
            }
            mkProcessSpan.end()

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
        performAndWait(timeout: explicitTimeout) { [self] in
            for var processor in childProcessors {
                processor.shutdown(explicitTimeout: explicitTimeout)
            }
            for exporter in childExporters {
                exporter.shutdown(explicitTimeout: explicitTimeout)
            }
        }
    }

    // MARK: - Private

    /// Whether the caller is already running on `processorQueue`, e.g. from inside a child processor or exporter callback.
    private var isOnProcessorQueue: Bool {
        DispatchQueue.getSpecific(key: processorQueueKey) != nil
    }

    /// Whether `criticalResourceGroup` has been left (or was never set).
    ///
    /// Until then, every span block queued on `processorQueue` waits on the group, so a synchronous wait
    /// behind them would last until the SDK finishes starting, and forever if the caller is the thread starting it.
    private var isCriticalResourceGroupReady: Bool {
        criticalResourceGroup?.wait(timeout: .now()) != .timedOut
    }

    /// Runs `work` on `processorQueue` and blocks the caller until it finishes or `timeout` elapses.
    ///
    /// - Runs `work` inline when already on `processorQueue`, since waiting on it from there would never return.
    /// - Doesn't block while `criticalResourceGroup` is still closed. `work` stays queued and runs once the SDK has started.
    /// - Waits at most `timeout`, or `defaultBlockingTimeout` when `nil`. When the wait times out, `work` still runs later.
    private func performAndWait(timeout: TimeInterval?, _ work: @escaping () -> Void) {
        if isOnProcessorQueue {
            work()
            return
        }

        guard isCriticalResourceGroupReady else {
            processorQueue.async(execute: work)
            return
        }

        let group = DispatchGroup()
        processorQueue.async(group: group, execute: work)
        _ = group.wait(timeout: .now() + (timeout ?? Self.defaultBlockingTimeout))
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
