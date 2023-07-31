
import OpenTelemetryApi

public class EmbraceTracer: Tracer {

    public func spanBuilder(spanName: String) -> SpanBuilder {

        return EmbraceSpanBuilder(spanName: spanName)
    }
}
