//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal
import EmbraceSemantics
import OpenTelemetryApi
import OpenTelemetrySdk

@objc(EMBEmbraceOTel)
public final class EmbraceOTel: NSObject {

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
        tracer(instrumentationName: instrumentationName, instrumentationVersion: instrumentationVersion)
    }

    /// Retrieve a tracer for the given instrumentation metadata
    /// - Parameters
    ///     - instrumentationName: the name of the instrumentation library, not the name of the instrumented library
    ///     - instrumentationVersion: The version of the instrumentation library (e.g., "semver:1.0.0"). Optional
    ///  - Returns An OpenTelemetry Tracer instance
    public func tracer(instrumentationName: String, instrumentationVersion: String? = nil) -> Tracer {
        OpenTelemetry.instance.tracerProvider.get(
            instrumentationName: instrumentationName,
            instrumentationVersion: instrumentationVersion
        )
    }

    // MARK: - Tracing

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
                            key: SpanSemantics.keyEmbraceType,
                            value: type.rawValue
                        )

        for (key, value) in attributes {
            builder.setAttribute(key: key, value: value)
        }

        return builder
    }

    // MARK: - Logging

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

        let otelAttributes = attributes.reduce(into: [:]) {
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
