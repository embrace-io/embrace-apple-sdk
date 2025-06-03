import Foundation
import QuartzCore

#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceCommonInternal
import EmbraceSemantics
import EmbraceOTelInternal
import EmbraceConfiguration
#endif
import OpenTelemetryApi

/// Manages tracing spans for SwiftUI view instrumentation.
///
/// Provides both one-off spans and cycle-based spans that automatically
/// terminate at the next run loop cycle. Ensures spans are nested correctly
/// and enforces execution on the main thread.
@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6.0, *)
final internal class EmbraceTraceViewLogger {
    
    /// Shared singleton instance used throughout the app for SwiftUI tracing.
    static let shared = EmbraceTraceViewLogger(
        otel: Embrace.client,
        logger: Embrace.logger,
        config: Embrace.client?.config?.configurable
    )
    
    /// Initializes a new trace phase manager.
    ///
    /// - Parameters:
    ///   - otel: The OpenTelemetry client used to build and record spans.
    ///   - logger: Internal logger for diagnostic messages.
    ///   - config: Configuration object.
    /// - Precondition: Must be called on the main thread.
    init(otel: EmbraceOpenTelemetry?, logger: InternalLogger?, config: EmbraceConfigurable?) {
        dispatchPrecondition(condition: .onQueue(.main))
        self.otel = otel
        self.logger = logger
        self.config = config
    }
    
    /// Cleans up and validates that no pending spans remain.
    /// - Precondition: Must be called on the main thread.
    deinit {
        dispatchPrecondition(condition: .onQueue(.main))
    }

    /// The OpenTelemetry client used to create spans.
    internal let otel: EmbraceOpenTelemetry?
    /// Logger for internal tracing diagnostics and errors.
    internal let logger: InternalLogger?
    /// Configuration for enabling/disabling features
    internal let config: EmbraceConfigurable?
}

// MARK: - Private Span Management

extension EmbraceTraceViewLogger {
    func startSpan(_ name: String, semantics: String, time: Date? = nil, parent: Span? = nil, attributes: [String: String]? = nil, _ function: StaticString = #function) -> OpenTelemetryApi.Span? {
        
        dispatchPrecondition(condition: .onQueue(.main))
        
        guard let config, config.isSwiftUiViewInstrumentationEnabled else {
            logger?.debug("SwiftUI View tracing is disabled, we won't be logging from EmbraceTraceViewLogger.")
            return nil
        }
        
        guard let client = otel else {
            logger?.debug("OTel client is unavailable, we won't be logging from EmbraceTraceViewLogger.")
            return nil
        }
        
        let builder = client.buildSpan(
            name: "[\(name)]-\(semantics)",
            type: SpanType.viewLoad,
            attributes: attributes ?? [:],
            autoTerminationCode: nil
        )
        
        if let time {
            builder.setStartTime(time: time)
        }

        if let parent {
            builder.setParent(parent)
        }

        return builder.startSpan()
    }
    
    func endSpan(_ span: OpenTelemetryApi.Span?, errorCode: SpanErrorCode? = nil, _ function: StaticString = #function) {
        
        dispatchPrecondition(condition: .onQueue(.main))
        guard let span else {
            return
        }
        span.end(errorCode: errorCode)
    }
}
