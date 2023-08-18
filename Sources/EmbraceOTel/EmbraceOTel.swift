import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

// Android implementation
// https://github.com/embrace-io/embrace-android-sdk3/blob/561fd6b24de0e889f08d154478be132302daa0d0/embrace-android-sdk/src/main/java/io/embrace/android/embracesdk/internal/spans/SpansServiceImpl.kt
@objc public final class EmbraceOTel: NSObject {

    let instrumentationName = "Embrace"
    let instrumentationVersion = "semver:0.0.1"

    private override init() {
        fatalError("This init is not available")
    }

    public static func createEmbraceBatchProcessor(configuration: ExporterConfiguration) -> SpanProcessor {
        let exporter = EmbraceSpanExporter(configuration: configuration)
        return BatchSpanProcessor(spanExporter: exporter)
    }

    public init(spanProcessor: SpanProcessor) {
        OpenTelemetry.registerTracerProvider(tracerProvider:
                                                TracerProviderBuilder()
                                                    .add(spanProcessor: spanProcessor)
                                                    .build() )

        super.init()
    }

    // tracer
    internal var tracer: Tracer {
        OpenTelemetry.instance.tracerProvider.get(
            instrumentationName: instrumentationName,
            instrumentationVersion: instrumentationVersion)
    }

    // methods to add span

    public func addSpan<T>(
        name: String,
        type: EmbraceSemantics.SpanType,
        attributes: [String: String] = [:],
        spanOperation: () -> T
    ) -> T {
        let builder = buildSpan(name: name, type: type, attributes: attributes)
        let span = builder.startSpan()
        let result = spanOperation()
        span.end()

        return result
    }

    public func buildSpan(
        name: String,
        type: EmbraceSemantics.SpanType,
        attributes: [String: String] = [:]
    ) -> SpanBuilder {

        let builder = tracer.spanBuilder(spanName: name)
                        .setAttribute(
                            key: EmbraceSemantics.spanTypeAttributeKey,
                            value: type.rawValue )

        for (key, value) in attributes {
            builder.setAttribute(key: key, value: value)
        }

        return builder
    }

}
