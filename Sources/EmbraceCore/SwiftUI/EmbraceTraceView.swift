//
//  EmbraceTraceView.swift
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetryApi
import SwiftUI

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

/// A SwiftUI wrapper view that instruments performance tracing for any content.
///
/// Use `EmbraceTraceView` to automatically record:
///  - Body evaluation spans (each time SwiftUI recomputes the view)
///  - Appear and disappear events (when the view enters or leaves the screen)
///  - A “RenderLoop” span that groups all child spans in a single render tick
///
/// If tracing is disabled or the OTel client is unavailable, this view simply forwards
/// to `content()` without additional overhead (only invokes an empty `onAppear`/`onDisappear`).
///
/// - Note: For best results, apply this wrapper to performance-critical screens or components
///         rather than trivial, frequently re-rendered subviews.
///
/// **Example Usage:**
/// ```swift
/// EmbraceTraceView("HomeScreen") {
///     HomeView()
/// }
///
/// EmbraceTraceView("ProfileDetail",
///                  attributes: ["user_id": someUser.id]) {
///     ProfileDetailView(user: someUser)
/// }
/// ```
@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6.0, *)
public struct EmbraceTraceView<Content: View, Value: Equatable>: View {
    @Environment(\.embraceTraceViewContext)
    private var context: EmbraceTraceViewContext

    @Environment(\.embraceTraceViewLogger)
    private var logger: EmbraceTraceViewLogger

    @State
    private var state: EmbraceTraceViewState<Value> = EmbraceTraceViewState()

    private let content: () -> Content
    private let name: String
    private let attributes: [String: String]?
    private let contentCompleteValue: Value?

    /// Creates a new `EmbraceTraceView` that wraps the given content for tracing.
    ///
    /// - Parameters:
    ///   - viewName: The stable identifier used in trace dashboards (e.g., screen or component name).
    ///   - attributes: Optional metadata to associate with all spans created by this view.
    ///   - contentComplete: Optional value representing the "content complete" state.
    ///   - content: A closure returning the view content to wrap.
    public init(
        _ viewName: String,
        attributes: [String: String]? = nil,
        contentComplete: Value? = nil,
        content: @escaping () -> Content
    ) {
        self.name = viewName
        self.attributes = attributes
        self.content = content
        self.contentCompleteValue = contentComplete

        // Ensure counters are updated
        if self.state.initialize == 0 {
            self.state.initializeTime = Date()
        }
        self.state.initialize += 1

        if !self.state.contentCompleteStoredFirstValue {
            self.state.contentCompleteStoredFirstValue = true
            self.state.contentCompleteValue = contentComplete
        }
    }

    public init(
        _ viewName: String,
        attributes: [String: String]? = nil,
        content: @escaping () -> Content
    ) where Value == Never {
        self.init(
            viewName,
            attributes: attributes,
            contentComplete: nil,
            content: content
        )
    }

    public var body: some View {
        // If tracing is disabled or we lack a valid OTel client, just render content.
        guard let config = logger.config,
            config.isSwiftUiViewInstrumentationEnabled
        else {
            return content()
                .onAppear()  // placeholder to satisfy return type
                .onDisappear()
        }

        let startTime = Date()

        // Ensure counters are updated
        state.bodyTime = startTime
        state.body += 1

        // If no _RenderLoop_ span exists for this render tick, create one.
        if context.firstCycleSpan == nil {
            // Capture a local reference to avoid capturing `self` (and its generic types)
            let ctx = context
            context.firstCycleSpan = logger.cycledSpan(
                name,
                semantics: SpanSemantics.SwiftUIView.renderLoopName,
                time: startTime,
                parent: nil,
                attributes: attributes
            ) { [weak ctx] in
                // Reset cycle root after the run loop tick completes on the main actor
                Task { @MainActor in
                    ctx?.firstCycleSpan = nil
                }
            }
        }

        // Start a span for this body evaluation
        let bodySpan = logger.startSpan(
            name,
            semantics: SpanSemantics.SwiftUIView.bodyName,
            time: startTime,
            parent: context.firstCycleSpan,
            attributes: attributes
        )
        defer {
            logger.endSpan(bodySpan)
        }

        // Check for a change in the content complete value
        if contentCompleteValue != state.contentCompleteValue {
            // Ensure values are udpated
            state.contentComplete += 1
            state.contentCompleteValue = contentCompleteValue
            state.contentCompleteTime = startTime

            // if it's the first time, send out
            // the content complete span.
            if state.contentComplete == 1, let initializeTime = state.initializeTime {
                let span = logger.startSpan(
                    name,
                    semantics: SpanSemantics.SwiftUIView.timeToFirstContentComplete,
                    time: initializeTime,
                    parent: nil,
                    attributes: attributes
                )
                logger.endSpan(span, time: startTime)
            }
        }

        return content()
            .onAppear {
                let time = Date()

                // Ensure counters are updated
                state.appearTime = time
                state.appear += 1

                // If this is the first appearance,
                // log this as time to first render.
                if state.appear == 1,
                    let startTime = state.initializeTime
                {
                    let span = logger.startSpan(
                        name,
                        semantics: SpanSemantics.SwiftUIView.timeToFirstRender,
                        time: startTime,
                        parent: nil,
                        attributes: attributes
                    )
                    logger.endSpan(span, time: time)
                }

                // Create and end an “appear” span for this view
                logger.cycledSpan(
                    name,
                    semantics: SpanSemantics.SwiftUIView.appearName,
                    time: time,
                    parent: context.firstCycleSpan,
                    attributes: attributes
                ) {}
            }
            .onDisappear {
                let time = Date()

                // Ensure counters are updated
                state.disappearTime = time
                state.disappear += 1

                // Create and end a “disappear” span for this view
                logger.cycledSpan(
                    name,
                    semantics: SpanSemantics.SwiftUIView.disappearName,
                    time: time,
                    parent: context.firstCycleSpan,
                    attributes: attributes
                ) {}
            }
    }
}
