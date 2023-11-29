//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi

class EmbraceSpanBuilder: SpanBuilder {

    private let spanName: String
    private let spanProcessor: EmbraceSpanProcessor
    private var startTime: Date?

    private var parent: SpanContext?
    private var spanKind = SpanKind.internal

    private var attributes = [String: AttributeValue]()
    private var events = [RecordingSpanEvent]()
    private var links = [RecordingSpanLink]()

    private var startAsActive: Bool = false

    init(spanName: String, processor: EmbraceSpanProcessor) {
        self.spanName = spanName
        self.spanProcessor = processor
    }

    @discardableResult func setParent(_ parent: OpenTelemetryApi.SpanContext) -> Self {
        self.parent = parent
        return self
    }

    @discardableResult func setParent(_ parent: OpenTelemetryApi.Span) -> Self {
        return setParent(parent.context)
    }

    @discardableResult func setNoParent() -> Self {
        parent = nil
        return self
    }

    @discardableResult func setAttribute(key: String, value: OpenTelemetryApi.AttributeValue) -> Self {
        attributes[key] = value
        return self
    }

    @discardableResult func addLink(spanContext: OpenTelemetryApi.SpanContext) -> Self {
        links.append(.init(traceId: spanContext.traceId, spanId: spanContext.spanId))
        return self
    }

    @discardableResult func addLink(spanContext: OpenTelemetryApi.SpanContext, attributes: [String: OpenTelemetryApi.AttributeValue]) -> Self {
        links.append(.init(traceId: spanContext.traceId, spanId: spanContext.spanId, attributes: attributes))
        return self
    }

    @discardableResult func setSpanKind(spanKind: OpenTelemetryApi.SpanKind) -> Self {
        self.spanKind = spanKind
        return self
    }

    @discardableResult func setStartTime(time: Date) -> Self {
        self.startTime = time
        return self
    }

    @discardableResult func setActive(_ active: Bool) -> Self {
        startAsActive = active
        return self
    }

    func startSpan() -> OpenTelemetryApi.Span {
        let context = SpanContext.create(
            traceId: parent?.traceId ?? TraceId.random(),
            spanId: SpanId.random(),
            traceFlags: parent?.traceFlags ?? TraceFlags(),
            traceState: parent?.traceState ?? TraceState()
        )

        let span = RecordingSpan(
            startTime: self.startTime ?? Date(),
            kind: spanKind,
            context: context,
            parentContext: parent,
            name: spanName,
            attributes: attributes,
            events: events,
            links: links,
            processor: spanProcessor
        )

        if startAsActive {
            OpenTelemetry.instance.contextProvider.setActiveSpan(span)
        }

        spanProcessor.onStart(span: span)
        return span
    }

}
