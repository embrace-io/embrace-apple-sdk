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
        processorQueue.sync {
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

    func shutdown(explicitTimeout: TimeInterval?) {
        processorQueue.sync {
            for var processor in childProcessors {
                processor.shutdown(explicitTimeout: explicitTimeout)
            }
            for exporter in childExporters {
                exporter.shutdown(explicitTimeout: explicitTimeout)
            }
        }
    }

    // MARK: - Private

    /// Stamps external spans with required Embrace attributes before they reach child processors
    /// or the `EmbraceCore` delegate.
    private func injectAttributes(_ span: ReadableSpan, delegate: EmbraceSpanProcessorDelegate) {
        span.setAttribute(key: SpanSemantics.keyEmbraceType, value: .string(EmbraceType.performance.rawValue))
        span.setAttribute(key: SpanSemantics.Session.keyState, value: .string(delegate.currentSessionState.rawValue))
        if let sessionId = delegate.currentSessionId, !sessionId.stringValue.isEmpty {
            span.setAttribute(key: SpanSemantics.keySessionId, value: .string(sessionId.stringValue))
        }
    }
}
