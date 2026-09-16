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

/// Bridges `EmbraceCore` lifecycle events into the OpenTelemetry SDK and intercepts
/// externally-created OTel signals back into `EmbraceCore`.
///
/// **Outbound** (Core → OTel): Implements `EmbraceOTelSignalBridge` — each Core callback
/// creates or mutates an OTel span/log via the owned `TracerProvider`/`LoggerProvider`.
///
/// **Inbound** (OTel → Core): The `EmbraceSpanProcessor` and `EmbraceLogProcessor` are
/// inserted at the front of each provider's processor chain. They forward external signals
/// (not present in the bridge's caches) to `EmbraceOTelDelegate`.
final package class EmbraceOTelBridge {

    // MARK: - Properties

    weak var delegate: (any EmbraceOTelDelegate)?
    weak var metadataProvider: (any EmbraceMetadataProvider)?

    private let tracerProvider: TracerProviderSdk
    private let loggerProvider: LoggerProviderSdk
    private let tracer: any Tracer
    private let logger: any OpenTelemetryApi.Logger

    // Cache mapping Embrace spanId (hex) → live OTel Span.
    // Populated on startSpan, cleared on endSpan.
    private let spanCache = EmbraceMutex([String: any OpenTelemetryApi.Span]())

    // IDs pre-reserved by the bridge before calling builder.startSpan().
    // Covers the onStart window: the ID is inserted here before startSpan() is called, so
    // isInternalSpan correctly returns true when onStart fires synchronously during startSpan().
    private let pendingSpanIds = EmbraceMutex(Set<String>())

    // Cache of IDs for logs emitted outbound so the inbound processor can skip them.
    private let internalLogIds = EmbraceMutex(Set<String>())

    private let idGenerator = EmbraceSpanIdGenerator()
    private let spanProcessor: EmbraceSpanProcessor
    private let logProcessor: EmbraceLogProcessor

    // MARK: - Init

    package init(
        resource: Resource? = nil,
        spanProcessors: [SpanProcessor] = [],
        spanExporters: [SpanExporter] = [],
        logProcessors: [LogRecordProcessor] = [],
        logExporters: [LogRecordExporter] = []
    ) {
        // EmbraceSpanProcessor owns the user-supplied child processors and exporters,
        // making it the single root processor registered with the TracerProviderSdk.
        let embraceSpanProcessor = EmbraceSpanProcessor(
            childProcessors: spanProcessors,
            childExporters: spanExporters
        )

        // EmbraceLogProcessor owns the user-supplied child processors and exporters,
        // making it the single root processor registered with the LoggerProviderSdk.
        let embraceLogProcessor = EmbraceLogProcessor(
            childProcessors: logProcessors,
            childExporters: logExporters
        )

        // The default event count limit is 128. Raise it to 9999 to support breadcrumbs,
        // which rely on span events and can easily exceed the default cap.
        let spanLimits = SpanLimits().settingEventCountLimit(9999)

        let passedResource = resource ?? Resource()
        tracerProvider = TracerProviderSdk(idGenerator: idGenerator, resource: passedResource, spanLimits: spanLimits, spanProcessors: [embraceSpanProcessor])
        loggerProvider = LoggerProviderSdk(resource: passedResource, logRecordProcessors: [embraceLogProcessor])

        tracer = tracerProvider.get(instrumentationName: "EmbraceTracer", instrumentationVersion: nil)
        logger = loggerProvider.loggerBuilder(instrumentationScopeName: "EmbraceLogger").build()

        spanProcessor = embraceSpanProcessor
        logProcessor = embraceLogProcessor

        // Wire the processors to self as their delegate.
        spanProcessor.delegate = self
        logProcessor.delegate = self
    }

    // MARK: - Configuration

    /// Called after `Embrace.setup()` completes to attach the Core-side delegate, metadata provider,
    /// and the `captureServicesGroup` that gates child span forwarding until the SDK is ready.
    package func setup(
        delegate: any EmbraceOTelDelegate,
        metadataProvider: any EmbraceMetadataProvider,
        criticalResourceGroup: DispatchGroup? = nil
    ) {
        self.delegate = delegate
        self.metadataProvider = metadataProvider
        spanProcessor.criticalResourceGroup = criticalResourceGroup
    }
}

// MARK: - EmbraceOTelSignalBridge

extension EmbraceOTelBridge: EmbraceOTelSignalBridge {

    package func startSpan(
        name: String,
        parentSpan: EmbraceSpan?,
        status: EmbraceSpanStatus,
        startTime: Date,
        endTime: Date?,
        events: [EmbraceSpanEvent],
        links: [EmbraceSpanLink],
        attributes: EmbraceAttributes
    ) -> EmbraceSpanContext {
        var builder = tracer.spanBuilder(spanName: name).setStartTime(time: startTime)

        // Parentage is always stated explicitly, never left to the builder's default.
        //
        // A span builder with no parent set resolves one from the currently active span, which
        // lives in a process-wide store shared with every other OpenTelemetry user in the app.
        // Leaving that to chance would let an unrelated span become the parent of a span that
        // was meant to start its own trace, and the resulting trace id would not match the one
        // recorded alongside it.
        if let parentSpan {
            let parentId = parentSpan.context.spanId

            if let otelParent = spanCache.withLock({ $0[parentId] }) {
                builder = builder.setParent(otelParent)

            } else {
                // The cache only holds spans that are still open, but parenting in OTel is a
                // relationship between identifiers: a parent that already ended, or one that was
                // never created through this bridge, is still a valid parent. Rebuilding the
                // context from the identifiers keeps the child in the parent's trace.
                //
                // The identifiers are validated first: `SpanId(fromHexString:)` traps on strings
                // shorter than 16 characters, so they can't be handed to it unchecked.
                if let parentContext = Self.otelContext(from: parentSpan.context) {
                    builder = builder.setParent(parentContext)

                } else {
                    // The identifiers can't be honored, so start a new trace rather than falling
                    // back to the active span.
                    builder = builder.setNoParent()
                }
            }

        } else {
            builder = builder.setNoParent()
        }

        // Set links before starting (only supported at creation time).
        for link in links {
            if let ctx = Self.otelContext(from: link.context) {
                builder = builder.addLink(spanContext: ctx, attributes: link.attributes.otelAttributes)
            }
        }

        // Apply attributes, status, and events after starting.
        for (key, value) in attributes {
            builder.setAttribute(key: key, value: value.otelAttributeValue)
        }

        // Pre-reserve the span ID so isInternalSpan returns true when onStart fires synchronously
        // during startSpan(), before the span can be added to spanCache.
        let reservedId = idGenerator.reserveNextSpanId().hexString
        pendingSpanIds.withLock { $0.insert(reservedId) }
        let otelSpan = builder.startSpan()
        pendingSpanIds.withLock { $0.remove(reservedId) }

        // Set status
        otelSpan.status = status.otelStatus

        // Add events
        for event in events {
            otelSpan.addEvent(name: event.name, attributes: event.attributes.otelAttributes, timestamp: event.timestamp)
        }

        let spanId = otelSpan.context.spanId.hexString
        let traceId = otelSpan.context.traceId.hexString

        // Cache the span for future mutation callbacks.
        spanCache.withLock { $0[spanId] = otelSpan }

        // If endTime is provided, end the span immediately.
        // end() fires onEnd synchronously — the span must still be in the cache at that point.
        if let endTime {
            otelSpan.end(time: endTime)
            spanCache.withLock { $0[spanId] = nil }
        }

        return EmbraceSpanContext(spanId: spanId, traceId: traceId)
    }

    /// Converts an `EmbraceSpanContext` into the OTel equivalent, or returns `nil` when its
    /// identifiers can't refer to a span.
    ///
    /// The identifiers are checked before being parsed: `SpanId(fromHexString:)` builds its string
    /// indices before validating the length, so it traps on anything shorter than 16 characters.
    private static func otelContext(from context: EmbraceSpanContext) -> SpanContext? {
        guard context.isValid else {
            return nil
        }

        let otelTraceId = TraceId(fromHexString: context.traceId)
        let otelSpanId = SpanId(fromHexString: context.spanId)

        guard otelTraceId.isValid, otelSpanId.isValid else {
            return nil
        }

        return SpanContext.create(
            traceId: otelTraceId,
            spanId: otelSpanId,
            traceFlags: .init(fromByte: 1),
            traceState: .init()
        )
    }

    package func updateSpanStatus(_ span: EmbraceSpan, status: EmbraceSpanStatus) {
        let id = span.context.spanId
        spanCache.withLock { $0[id] }?.status = status.otelStatus
    }

    package func updateSpanAttribute(_ span: EmbraceSpan, key: String, value: EmbraceAttributeValue?) {
        let id = span.context.spanId
        if let otelSpan = spanCache.withLock({ $0[id] }) {
            otelSpan.setAttribute(key: key, value: value?.otelAttributeValue)
        }
    }

    package func addSpanEvent(_ span: EmbraceSpan, event: EmbraceSpanEvent) {
        let id = span.context.spanId
        spanCache.withLock { $0[id] }?.addEvent(
            name: event.name,
            attributes: event.attributes.otelAttributes,
            timestamp: event.timestamp
        )
    }

    package func addSpanLink(_ span: EmbraceSpan, link: EmbraceSpanLink) {
        // OTel SDK does not support adding links after span creation. This is a no-op.
    }

    package func endSpan(_ span: EmbraceSpan, endTime: Date) {
        let id = span.context.spanId
        // Look up without removing first — the span must remain in the cache while end() fires
        // onEnd synchronously, so isInternalSpan correctly identifies it as an outbound signal.
        guard let otelSpan = spanCache.withLock({ $0[id] }) else { return }
        otelSpan.end(time: endTime)
        spanCache.withLock { $0[id] = nil }
    }

    package func waitForAllWork() {
        spanProcessor.waitForAllWork()
    }

    package func createLog(_ log: EmbraceLog) {
        let logId = log.id
        // Track the ID so the inbound processor can skip it.
        internalLogIds.withLock { $0.insert(logId) }

        var builder = logger.logRecordBuilder()
            .setTimestamp(log.timestamp)
            .setBody(.string(log.body))

        if let otelSeverity = Severity(rawValue: log.severity.rawValue) {
            builder = builder.setSeverity(otelSeverity)
        }

        var otelAttributes = log.attributes.otelAttributes
        otelAttributes[LogSemantics.keyId] = .string(logId)

        builder = builder.setAttributes(otelAttributes)
        builder.emit()
    }
}

// MARK: - EmbraceSpanProcessorDelegate

extension EmbraceOTelBridge: EmbraceSpanProcessorDelegate {

    package func isInternalSpan(_ span: ReadableSpan) -> Bool {
        let id = span.context.spanId.hexString
        // Check pendingSpanIds first: covers the onStart window before the span enters spanCache.
        if pendingSpanIds.withLock({ $0.contains(id) }) { return true }
        return spanCache.withLock { $0[id] != nil }
    }

    package func onExternalSpanStarted(_ span: ReadableSpan) {
        let adapter = OTelSpanAdapter(span: span, metadataProvider: metadataProvider)
        delegate?.onStartSpan(adapter)
    }

    package func onExternalSpanEnded(_ span: ReadableSpan) {
        let adapter = OTelSpanAdapter(span: span, metadataProvider: metadataProvider)
        delegate?.onEndSpan(adapter)
    }

    package var currentSessionState: SessionState {
        metadataProvider?.currentSessionState ?? .unknown
    }

    package var currentSessionId: EmbraceIdentifier? {
        metadataProvider?.currentSessionId
    }

    package var currentUserSessionId: EmbraceIdentifier? {
        metadataProvider?.currentUserSessionId
    }
}

// MARK: - EmbraceLogProcessorDelegate

extension EmbraceOTelBridge: EmbraceLogProcessorDelegate {

    package func isInternalLog(_ log: ReadableLogRecord) -> Bool {
        guard case let .string(logId) = log.attributes[LogSemantics.keyId] else {
            return false
        }
        return internalLogIds.withLock { $0.contains(logId) }
    }

    package func onExternalLogEmitted(_ log: ReadableLogRecord) {
        let adapter = OTelLogAdapter(logRecord: log, metadataProvider: metadataProvider)
        delegate?.onEmitLog(adapter)
    }
}
