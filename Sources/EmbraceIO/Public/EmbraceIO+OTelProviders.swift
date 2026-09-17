//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi

/// Access to the OpenTelemetry providers backing the Embrace pipeline.
///
/// Signals created through these providers are captured by Embrace and forwarded to any custom
/// processors and exporters supplied through `EmbraceIO.OTelOptions`, exactly like the signals the
/// SDK generates itself. They also count against the same per-session limits as
/// `createSpan(name:)` and `log(_:severity:)`.
///
/// Every accessor here returns `nil` when the SDK was started without `EmbraceIO.OTelOptions`,
/// because in that configuration no OpenTelemetry SDK instance is created at all. Nothing is
/// substituted in its place: a `nil` return makes the missing configuration visible at the call
/// site instead of silently discarding the telemetry.
extension EmbraceIO {

    /// The `TracerProvider` backing the Embrace pipeline, or `nil` when the SDK was started
    /// without `EmbraceIO.OTelOptions`.
    ///
    /// Use this to obtain tracers with options that `tracer(instrumentationName:instrumentationVersion:)`
    /// does not cover, such as a schema URL or instrumentation scope attributes.
    public var tracerProvider: TracerProvider? {
        otelBridge.safeValue?.otelTracerProvider
    }

    /// The `LoggerProvider` backing the Embrace pipeline, or `nil` when the SDK was started
    /// without `EmbraceIO.OTelOptions`.
    ///
    /// Use this to obtain loggers with options that `logger(instrumentationScopeName:instrumentationVersion:)`
    /// does not cover, such as a schema URL, instrumentation scope attributes, or control over
    /// whether the trace context is automatically attached.
    public var loggerProvider: LoggerProvider? {
        otelBridge.safeValue?.otelLoggerProvider
    }

    /// Returns a `Tracer` attached to the Embrace pipeline.
    ///
    /// - Parameters:
    ///   - instrumentationName: Name of the instrumentation library creating the spans. This is
    ///     the name of your instrumentation, not of the library being instrumented.
    ///   - instrumentationVersion: Version of the instrumentation library, if any.
    /// - Returns: The `Tracer`, or `nil` if the SDK was started without `EmbraceIO.OTelOptions`.
    public func tracer(instrumentationName: String, instrumentationVersion: String? = nil) -> Tracer? {
        tracerProvider?.get(
            instrumentationName: instrumentationName,
            instrumentationVersion: instrumentationVersion
        )
    }

    /// Returns a `Logger` attached to the Embrace pipeline.
    ///
    /// - Parameters:
    ///   - instrumentationScopeName: Name of the instrumentation library emitting the logs. This is
    ///     the name of your instrumentation, not of the library being instrumented.
    ///   - instrumentationVersion: Version of the instrumentation library, if any.
    /// - Returns: The `Logger`, or `nil` if the SDK was started without `EmbraceIO.OTelOptions`.
    public func logger(
        instrumentationScopeName: String,
        instrumentationVersion: String? = nil
    ) -> OpenTelemetryApi.Logger? {
        guard let loggerProvider else {
            return nil
        }

        // `LoggerProvider.get(instrumentationScopeName:)` takes the scope name alone; unlike the
        // tracer equivalent it has no overload carrying a version, which is only reachable through
        // the builder. Use the builder only when there is a version to set.
        guard let instrumentationVersion else {
            return loggerProvider.get(instrumentationScopeName: instrumentationScopeName)
        }

        let builder = loggerProvider.loggerBuilder(instrumentationScopeName: instrumentationScopeName)
        return builder.setInstrumentationVersion(instrumentationVersion).build()
    }
}
