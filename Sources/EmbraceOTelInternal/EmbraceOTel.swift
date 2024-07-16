import Foundation
import EmbraceCommonInternal
import OpenTelemetryApi
import OpenTelemetrySdk

@objc public final class EmbraceOTel: NSObject {

    let instrumentationName = "EmbraceOpenTelemetry"
    let instrumentationVersion = "semver:\(EmbraceMeta.sdkVersion)"

    /// Setup the OpenTelemetryApi
    /// - Parameter: spanProcessor The processor in which to run during the lifetime of each Span
    public static func setup(spanProcessors: [SpanProcessor]) {
        let resource = Resource()
        OpenTelemetry.registerTracerProvider(
            tracerProvider: TracerProviderSdk(
                resource: resource,
                spanProcessors: spanProcessors
            )
        )
    }

    public static func setup(logSharedState: EmbraceLogSharedState) {
        OpenTelemetry.registerLoggerProvider(loggerProvider: DefaultEmbraceLoggerProvider(sharedState: logSharedState))
    }

    internal var logger: Logger {
        OpenTelemetry.instance.loggerProvider.get(instrumentationScopeName: instrumentationName)
    }

    // tracer
    internal var tracer: Tracer {
        OpenTelemetry.instance.tracerProvider.get(
            instrumentationName: instrumentationName,
            instrumentationVersion: instrumentationVersion)
    }

    // methods to add span

    public func recordSpan<T>(
        name: String,
        type: SpanType,
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
        type: SpanType,
        attributes: [String: String] = [:]
    ) -> SpanBuilder {

        let builder = tracer.spanBuilder(spanName: name)
                        .setAttribute(
                            key: SpanAttributeKey.type,
                            value: type.rawValue )

        for (key, value) in attributes {
            builder.setAttribute(key: key, value: value)
        }

        return builder
    }

    public func log(
        _ message: String,
        severity: LogSeverity,
        attributes: [String: String]
    ) {
        log(message, severity: severity, timestamp: Date(), attributes: attributes)
    }

    public func log(
        _ message: String,
        severity: LogSeverity,
        timestamp: Date,
        attributes: [String: String]
    ) {
        let otelAttributes = attributes.reduce(into: [String: AttributeValue]()) {
            $0[$1.key] = AttributeValue.string($1.value)
        }
        logger
            .logRecordBuilder()
            .setBody(message)
            .setTimestamp(timestamp)
            .setAttributes(otelAttributes)
            .setSeverity(Severity.fromLogSeverity(severity) ?? .info)
            .emit()
    }
}
