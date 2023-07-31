
import OpenTelemetryApi
import Foundation

class EmbraceSpanBuilder: SpanBuilder {
    func setAttribute(key: String, value: OpenTelemetryApi.AttributeValue) -> Self {

        return self
    }

    private var spanName: String

    init(spanName: String) {
        self.spanName = spanName
    }

    func setParent(_ parent: OpenTelemetryApi.Span) -> Self {

        return self
    }
    
    func setParent(_ parent: OpenTelemetryApi.SpanContext) -> Self {

        return self
    }
    
    func setNoParent() -> Self {

        return self
    }
    
    func addLink(spanContext: OpenTelemetryApi.SpanContext) -> Self {

        return self
    }
    
    func addLink(spanContext: OpenTelemetryApi.SpanContext, attributes: [String : OpenTelemetryApi.AttributeValue]) -> Self {

        return self
    }
    
    func setSpanKind(spanKind: OpenTelemetryApi.SpanKind) -> Self {

        return self
    }
    
    func setStartTime(time: Date) -> Self {

        return self
    }
    
    func setActive(_ active: Bool) -> Self {

        return self
    }
    
    func startSpan() -> OpenTelemetryApi.Span {
        return NSObject() as! Span //TODO: fix this
    }

}
