//
//  EmbraceTraceViewLogger.swift
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import SwiftUI

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceConfiguration
    import EmbraceSemantics
#endif

/// The environment key for injecting `EmbraceTraceViewLogger` into SwiftUI's `EnvironmentValues`.
@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6.0, *)
private struct EmbraceTraceViewLoggerEnvironmentKey: EnvironmentKey {
    static let defaultValue: EmbraceTraceViewLogger = EmbraceTraceViewLogger(
        otel: Embrace.client?.otel,
        logger: Embrace.logger,
        config: Embrace.client?.config.configurable
    )
}

@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6.0, *)
extension EnvironmentValues {
    /// Provides the singleton `EmbraceTraceViewLogger` used by `EmbraceTraceView`.
    var embraceTraceViewLogger: EmbraceTraceViewLogger {
        get { self[EmbraceTraceViewLoggerEnvironmentKey.self] }
        set { self[EmbraceTraceViewLoggerEnvironmentKey.self] = newValue }
    }
}

/// Manages OpenTelemetry span creation and lifecycle specifically for SwiftUI view tracing.
///
/// - Responsibilities:
///   1. Check feature flags to determine if tracing is enabled.
///   2. Start and end spans on the main queue to capture timing for view body evaluations,
///      appear/disappear events, and render cycles.
///   3. Provide “cycled spans” that automatically terminate at the next run loop tick, so child
///      spans can be created within the same render cycle.
///
/// If any dependency (OTel client, configuration, etc.) is absent, tracing is effectively disabled.
@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6.0, *)
final class EmbraceTraceViewLogger {
    // MARK: – Properties

    /// The OTel signals handler, used to build and start spans.
    let otel: EmbraceOTelSignalsHandler?

    /// Internal logger for debug/error reporting related to span creation.
    let logger: InternalLogger?

    /// Configuration controlling feature flags, such as whether SwiftUI view tracing is on.
    let config: EmbraceConfigurable?

    // MARK: – Initialization

    /// Initializes a new `EmbraceTraceViewLogger`. Must be invoked on the main queue.
    ///
    /// - Parameters:
    ///   - otel: The `OTelSignalsHandler` client, or `nil` if not available.
    ///   - logger: The internal diagnostic logger, or `nil`.
    ///   - config: The configuration object controlling feature flags.
    ///
    /// If `otel` or `config` is `nil`, tracing calls become no-ops.
    init(
        otel: EmbraceOTelSignalsHandler?,
        logger: InternalLogger?,
        config: EmbraceConfigurable?
    ) {
        dispatchPrecondition(condition: .onQueue(.main))
        self.otel = otel
        self.logger = logger
        self.config = config
    }

    deinit {
        dispatchPrecondition(condition: .onQueue(.main))
    }
}

// MARK: – Span Management

extension EmbraceTraceViewLogger {
    /// Starts a new `EmbraceSpan` for a SwiftUI view event.
    ///
    /// - Parameters:
    ///   - name: The logical name of the view (same as passed to `EmbraceTraceView`).
    ///   - semantics: The semantic suffix (e.g., `"body"` or `"appear"`) used in span naming.
    ///   - time: Optional custom start time (defaults to `Date()`).
    ///   - parent: Optional parent span, so that child spans nest properly.
    ///   - attributes: Optional key/value metadata for enriching the span.
    ///   - function: Automatically captures the calling function name (for debug logs).
    ///
    /// - Returns: The started `EmbraceSpan`, or `nil` if tracing is disabled or the OTel client is missing.
    func startSpan(
        _ name: String,
        semantics: String,
        time: Date? = nil,
        parent: EmbraceSpan? = nil,
        attributes: [String: String]? = nil,
        _ function: StaticString = #function
    ) -> EmbraceSpan? {
        dispatchPrecondition(condition: .onQueue(.main))

        // Verify feature flag is on
        guard let config, config.isSwiftUiViewInstrumentationEnabled else {
            logger?.debug("SwiftUI view tracing is disabled. Skipping EmbraceTraceViewLogger.startSpan.")
            return nil
        }

        // Verify OpenTelemetry client
        guard let otel else {
            logger?.debug("OTel client unavailable. Skipping EmbraceTraceViewLogger.startSpan.")
            return nil
        }

        // Build the span with full name: "swiftui.view.<viewName>.<semantics>"
        return try? otel.createInternalSpan(
            name: "emb-swiftui.view.\(name).\(semantics)",
            parentSpan: parent,
            type: .viewLoad,
            attributes: attributes ?? [:]
        )
    }

    /// Ends the given span, optionally recording an error code.
    ///
    /// - Parameters:
    ///   - span: The `Span` to end (ignored if `nil`).
    ///   - time: Optional explicit end time (defaults to `Date()`).
    ///   - errorCode: Optional error code to attach to the span.
    ///   - function: Automatically captures the calling function name (for debug logs).
    func endSpan(
        _ span: EmbraceSpan?,
        time: Date? = nil,
        errorCode: EmbraceSpanErrorCode? = nil,
        _ function: StaticString = #function
    ) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard let span = span else { return }
        span.end(errorCode: errorCode, endTime: time ?? Date())
    }

    /// Creates a span that automatically ends on the next main run loop tick.
    ///
    /// Useful when you want to wrap child spans that occur within the same render cycle.
    /// The provided `completed` closure executes after ending this parent span.
    ///
    /// - Parameters:
    ///   - name: Logical view name (same as passed to `EmbraceTraceView`).
    ///   - semantics: Semantic suffix (e.g., `"cycle"`).
    ///   - time: Optional custom start time (defaults to `Date()`).
    ///   - parent: Optional parent span to nest under.
    ///   - attributes: Optional metadata dictionary.
    ///   - function: Automatically captures the calling function name (for debug logs).
    ///   - completed: Closure that runs after span termination on next run loop tick.
    ///
    /// - Returns: The started `EmbraceSpan`, or `nil` if tracing is disabled or no OTel client.
    @discardableResult
    func cycledSpan(
        _ name: String,
        semantics: String,
        time: Date? = nil,
        parent: EmbraceSpan? = nil,
        attributes: [String: String]? = nil,
        _ function: StaticString = #function,
        _ completed: @escaping () -> Void
    ) -> EmbraceSpan? {
        guard
            let span = startSpan(
                name,
                semantics: semantics,
                time: time,
                parent: parent,
                attributes: attributes,
                function
            )
        else {
            return nil
        }

        // Schedule end-of-span on next main run loop cycle so child spans can attach
        RunLoop.main.perform(inModes: [.common]) { [self] in
            endSpan(span)
            completed()
        }

        return span
    }
}
