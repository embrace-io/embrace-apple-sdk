import Foundation
import EmbraceCommon
import OpenTelemetryApi
import OpenTelemetrySdk
import EmbraceStorage

// Android implementation
// https://github.com/embrace-io/embrace-android-sdk3/blob/561fd6b24de0e889f08d154478be132302daa0d0/embrace-android-sdk/src/main/java/io/embrace/android/embracesdk/internal/spans/SpansServiceImpl.kt
@objc public final class EmbraceOTel: NSObject {

    let instrumentationName = "EmbraceTracer"
    let instrumentationVersion = "semver:0.0.1"

    /// Initial setup of the OpenTelemetry integration
    public static func setup(storage: EmbraceStorage) {
        let exporter = SpanExporter(configuration: .init(storage: storage))
        let spanProcessor = EmbraceSpanProcessor(spanExporter: exporter)

        OpenTelemetry.registerTracerProvider(
            tracerProvider: TracerProviderBuilder().add(spanProcessor: spanProcessor).build() )
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
        let span = buildSpan(name: name, type: type, attributes: attributes)
                        .startSpan()
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
                            key: EmbraceSemantics.AttributeKey.isKey,
                            value: type.rawValue )

        for (key, value) in attributes {
            builder.setAttribute(key: key, value: value)
        }

        return builder
    }
}
