import OpenTelemetryApi

public class EmbraceTracer: Tracer {

    let sharedState: SharedState

    init(sharedState: SharedState) {
        self.sharedState = sharedState
    }

    public func spanBuilder(spanName: String) -> SpanBuilder {

        return EmbraceSpanBuilder(spanName: spanName, sharedState: sharedState)
    }
}
