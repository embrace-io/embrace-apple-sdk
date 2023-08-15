import OpenTelemetryApi
import Foundation

class EmbraceSpanBuilder: SpanBuilder {

    private enum ParentType {
        case currentSpan
        case explicitParent
        case explicitRemoteParent
        case noParent
    }

    private var spanName: String
    private var spanKind = SpanKind.internal

    private var parent: Span?
    private var remoteParent: SpanContext?
    private var parentType: ParentType = .currentSpan

    private var attributes = [String: AttributeValue]()

    private var links = [EmbraceSpanData.Link]()
    private var totalNumberOfLinksAdded: Int = 0

    private var startAsActive: Bool = false

    private var startTime: Date?

    init(spanName: String) {
        self.spanName = spanName
    }

    @discardableResult func setNoParent() -> Self {
        parentType = .noParent
        remoteParent = nil
        parent = nil
        return self
    }

    @discardableResult func setParent(_ parent: OpenTelemetryApi.Span) -> Self {
        self.parent = parent
        remoteParent = nil
        parentType = .explicitParent
        return self
    }

    @discardableResult func setParent(_ parent: OpenTelemetryApi.SpanContext) -> Self {
        remoteParent = parent
        self.parent = nil
        parentType = .explicitRemoteParent
        return self
    }

    @discardableResult func addLink(spanContext: OpenTelemetryApi.SpanContext) -> Self {
        addLink(EmbraceSpanData.Link(context: spanContext))
        return self
    }

    @discardableResult func addLink(spanContext: OpenTelemetryApi.SpanContext, attributes: [String: OpenTelemetryApi.AttributeValue]) -> Self {
        addLink(EmbraceSpanData.Link(context: spanContext, attributes: attributes))
        return self
    }

    @discardableResult func addLink(_ link: EmbraceSpanData.Link) -> Self {
        totalNumberOfLinksAdded += 1
//        if links.count >= spanLimits.linkCountLimit {
//            return self
//        }
        links.append(link)
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

    @discardableResult func setAttribute(key: String, value: OpenTelemetryApi.AttributeValue) -> Self {
        self.attributes[key] = value
        return self
    }

    @discardableResult func setActive(_ active: Bool) -> Self {
        self.startAsActive = active
        return self
    }

    func startSpan() -> OpenTelemetryApi.Span {

        var parentContext = getParentContext(
            parentType: parentType,
            explicitParent: parent,
            remoteParent: remoteParent)

        let traceId: TraceId
        let spanId = SpanId.random() // TODO: Use TracerSharedState to use spanId generator
        var traceState = TraceState()

        if let parentContext = parentContext, parentContext.isValid {
            traceId = parentContext.traceId
            traceState = parentContext.traceState
        } else {
            traceId = TraceId.random() // TODO: Use TracerSharedState to use traceId generator
            parentContext = nil
        }

        let spanContext = SpanContext.create(
            traceId: traceId,
            spanId: spanId,
            traceFlags: TraceFlags(),
            traceState: traceState )

        let createdSpan = EmbraceSpan(
            context: spanContext,
            name: spanName,
            kind: .internal,
            startTime: startTime ?? Date(),
            parentContext: parentContext,
            attributes: attributes,
            links: links
        )

        if startAsActive {
            OpenTelemetry.instance.contextProvider.setActiveSpan(createdSpan)
        }

        return createdSpan
    }

}

private extension EmbraceSpanBuilder {

    private func getParentContext(parentType: ParentType, explicitParent: Span?, remoteParent: SpanContext?) -> SpanContext? {

        let currentSpan = OpenTelemetry.instance.contextProvider.activeSpan

        var parentContext: SpanContext?
        switch parentType {
        case .noParent:
            parentContext = nil
        case .currentSpan:
            parentContext = currentSpan?.context
        case .explicitParent:
            parentContext = explicitParent?.context
        case .explicitRemoteParent:
            parentContext = remoteParent
        }

        return parentContext
    }

}
