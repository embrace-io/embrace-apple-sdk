//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceCommonInternal
import EmbraceSemantics
#endif
import OpenTelemetryApi
import OpenTelemetrySdk

@objc(EMBEmbraceOTel)
public final class EmbraceOTel: NSObject {

    let instrumentationName = "EmbraceOpenTelemetry"
    let instrumentationVersion = "semver:\(EmbraceMeta.sdkVersion)"


    public private(set) static var processor: SingleSpanProcessor?

    /// Setup the OpenTelemetryApi
    /// - Parameter: spanProcessor The processor in which to run during the lifetime of each Span
    public static func setup(spanProcessors: [SpanProcessor]) {
        let resource = Resource()

        // the default span event limit was 128 but we need a way higher limit
        // this will mainly be used to apply breadcrumb limits when building the payloads
        let limits = SpanLimits()
            .settingEventCountLimit(9999)

        OpenTelemetry.registerTracerProvider(
            tracerProvider: TracerProviderSdk(
                resource: resource,
                spanLimits: limits,
                spanProcessors: spanProcessors
            )
        )

        processor = spanProcessors.first(where: { $0 is SingleSpanProcessor }) as? SingleSpanProcessor
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
}

extension EmbraceOTel: EmbraceOTelBridge {

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
            .setBody(.string(message))
            .setTimestamp(timestamp)
            .setAttributes(otelAttributes)
            .setSeverity(Severity.fromLogSeverity(severity) ?? .info)
            .emit()
    }
}

public protocol EmbraceOTelBridge: AnyObject {
    func buildSpan(
        name: String,
        type: SpanType,
        attributes: [String: String]
    ) -> SpanBuilder

    func log(
        _ message: String,
        severity: LogSeverity,
        timestamp: Date,
        attributes: [String: String]
    )
}
