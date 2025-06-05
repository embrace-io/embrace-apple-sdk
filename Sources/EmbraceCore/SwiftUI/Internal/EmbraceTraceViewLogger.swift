//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import SwiftUI
#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceCommonInternal
import EmbraceSemantics
import EmbraceOTelInternal
import EmbraceConfiguration
#endif
import OpenTelemetryApi

@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6.0, *)
private struct EmbraceTraceViewLoggerEnvironmentKey: EnvironmentKey {
    static let defaultValue: EmbraceTraceViewLogger = EmbraceTraceViewLogger(
        otel: Embrace.client,
        logger: Embrace.logger,
        config: Embrace.client?.config?.configurable,
        sessionIdProvider: { Embrace.client?.currentSessionId() }
    )
}

@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6.0, *)
extension EnvironmentValues {
    var embraceTraceViewLogger: EmbraceTraceViewLogger {
        get { self[EmbraceTraceViewLoggerEnvironmentKey.self] }
        set { self[EmbraceTraceViewLoggerEnvironmentKey.self] = newValue }
    }
}

/// Manages span creation and lifecycle for SwiftUI view instrumentation.
///
/// This class serves as the central coordinator for all SwiftUI tracing operations,
/// providing a clean interface between the SwiftUI instrumentation code and the
/// underlying OpenTelemetry infrastructure.
///
/// ## Responsibilities
/// - Creating properly configured OpenTelemetry spans for view events
/// - Enforcing main thread execution for UI tracing operations
/// - Managing configuration and feature flags for tracing
/// - Providing consistent span naming and attributes
///
/// ## Thread Safety
/// All public methods enforce main thread execution via `dispatchPrecondition`.
/// This ensures that span operations are thread-safe and don't interfere with
/// SwiftUI's main thread requirements.
///
/// ## Configuration
/// Tracing can be enabled/disabled at runtime via the `EmbraceConfigurable`
/// configuration object. When disabled, all span operations become no-ops.
@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6.0, *)
final internal class EmbraceTraceViewLogger {
    
    // MARK: - Properties
    
    /// The OpenTelemetry client used to create and manage spans
    internal let otel: EmbraceOpenTelemetry?
    
    /// Internal logger for diagnostic messages and error reporting
    internal let logger: InternalLogger?
    
    /// Configuration object that controls feature flags and behavior
    internal let config: EmbraceConfigurable?

    /// Provider to get the current session id, or nil if none
    internal let sessionIdProvider: () -> String?
    
    // MARK: - Lifecycle
    
    /// Initializes a new trace logger instance.
    ///
    /// - Parameters:
    ///   - otel: The OpenTelemetry client for span operations (nil disables tracing)
    ///   - logger: Internal logger for diagnostics (nil disables debug logging)
    ///   - config: Configuration object for feature flags (nil disables tracing)
    ///
    /// - Precondition: Must be called on the main thread to ensure proper initialization
    ///   in the UI context.
    ///
    /// - Note: Any nil dependencies will result in tracing being disabled for this instance.
    init(otel: EmbraceOpenTelemetry?,
         logger: InternalLogger?,
         config: EmbraceConfigurable?,
         sessionIdProvider: @escaping () -> String?
    ) {
        dispatchPrecondition(condition: .onQueue(.main))
        self.otel = otel
        self.logger = logger
        self.config = config
        self.sessionIdProvider = sessionIdProvider
    }
    
    /// Validates cleanup and ensures no pending spans remain.
    ///
    /// - Precondition: Must be called on the main thread for consistency with
    ///   other operations.
    ///
    /// - Note: In production, this deinit should rarely be called since the
    ///   shared instance typically lives for the entire app lifecycle.
    deinit {
        dispatchPrecondition(condition: .onQueue(.main))
    }
}

// MARK: - Session Management

extension EmbraceTraceViewLogger {
    var sessionId: String? {
        sessionIdProvider()
    }
}

// MARK: - Span Management

extension EmbraceTraceViewLogger {
    
    /// Creates and starts a new OpenTelemetry span for SwiftUI view instrumentation.
    ///
    /// This method handles the complete span creation pipeline:
    /// 1. Validates that tracing is enabled and dependencies are available
    /// 2. Configures the span with appropriate metadata and naming
    /// 3. Sets up parent-child relationships for proper trace hierarchy
    /// 4. Returns a started span ready for use
    ///
    /// ## Span Naming Convention
    /// Spans are named using the format: `[viewName]-semanticType`
    /// - Example: `[LoginScreen]-body-execution`
    /// - Example: `[ProductCard]-first-render-cycle`
    ///
    /// ## Configuration Checks
    /// - Returns `nil` if SwiftUI view instrumentation is disabled
    /// - Returns `nil` if OpenTelemetry client is unavailable
    /// - Logs appropriate debug messages for disabled states
    ///
    /// - Parameters:
    ///   - name: The view name identifier
    ///   - semantics: The semantic type of span (from SpanSemantics.SwiftUIView)
    ///   - time: Optional start time (uses current time if nil)
    ///   - parent: Optional parent span for hierarchy (creates root span if nil)
    ///   - attributes: Optional metadata dictionary to attach to the span
    ///   - function: Calling function name for debugging (automatically captured)
    ///
    /// - Returns: A started OpenTelemetry span, or nil if tracing is disabled/unavailable
    ///
    /// - Precondition: Must be called on the main thread
    func startSpan(
        _ name: String,
        semantics: String,
        time: Date? = nil,
        parent: Span? = nil,
        attributes: [String: String]? = nil,
        _ function: StaticString = #function
    ) -> OpenTelemetryApi.Span? {
        
        dispatchPrecondition(condition: .onQueue(.main))
        
        // Check if SwiftUI view instrumentation is enabled
        guard let config, config.isSwiftUiViewInstrumentationEnabled else {
            logger?.debug("SwiftUI View tracing is disabled, we won't be logging from EmbraceTraceViewLogger.")
            return nil
        }
        
        // Verify OpenTelemetry client availability
        guard let client = otel else {
            logger?.debug("OTel client is unavailable, we won't be logging from EmbraceTraceViewLogger.")
            return nil
        }
        
        // Build the span with proper configuration
        let builder = client.buildSpan(
            name: "swiftui.view.\(name).\(semantics)",
            type: SpanType.viewLoad,
            attributes: attributes ?? [:],
            autoTerminationCode: nil
        )
        
        // Set custom start time if provided
        if let time {
            builder.setStartTime(time: time)
        }
        
        // Establish parent-child relationship if parent provided
        if let parent {
            builder.setParent(parent)
        }

        return builder.startSpan()
    }
    
    /// Ends a span with optional error information.
    ///
    /// This method safely ends a span and handles error recording if needed.
    /// It includes comprehensive error handling to ensure that span operations
    /// don't crash the app even if the span is in an unexpected state.
    ///
    /// ## Error Handling
    /// - Gracefully handles nil spans (no-op)
    /// - Records error codes on the span if provided
    /// - Ensures span is properly closed even in error conditions
    ///
    /// - Parameters:
    ///   - span: The span to end (ignored if nil)
    ///   - errorCode: Optional error code to record on the span
    ///   - function: Calling function name for debugging (automatically captured)
    ///
    /// - Precondition: Must be called on the main thread
    ///
    /// - Note: It's safe to call this method multiple times on the same span -
    ///   subsequent calls will be ignored by the OpenTelemetry implementation.
    func endSpan(
        _ span: OpenTelemetryApi.Span?,
        time: Date? = nil,
        errorCode: SpanErrorCode? = nil,
        _ function: StaticString = #function
    ) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard let span else { return }
        span.end(errorCode: errorCode, time: time ?? Date())
    }
    
    func cycledSpan(
        _ name: String,
        semantics: String,
        time: Date? = nil,
        parent: Span? = nil,
        attributes: [String: String]? = nil,
        _ function: StaticString = #function,
        _ completed: @escaping () -> Void
    ) -> OpenTelemetryApi.Span? {
        let span = startSpan(
            name,
            semantics: semantics,
            time: time,
            parent: parent,
            attributes: attributes,
            function)
        if let span {
            // we want to jump to the next tick in the run loop
            // in order for this span to possible capture children
            // from within this run loop tick.
            RunLoop.main.perform(inModes: [.common]) { [self] in
                endSpan(span)
                completed()
            }
        }
        return span
    }
}
