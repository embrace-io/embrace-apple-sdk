//
//  EmbraceTraceView.swift
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import SwiftUI
import OpenTelemetryApi
#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceSemantics
#endif

/// A SwiftUI wrapper view that instruments performance tracing for any content.
///
/// Use `EmbraceTraceView` to automatically record:
///  - Body evaluation spans (each time SwiftUI recomputes the view)
///  - Appear and disappear events (when the view enters or leaves the screen)
///  - A “cycle” span that groups all child spans in a single render tick
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
public struct EmbraceTraceView<Content: View>: View {
    
    @Environment(\.embraceTraceViewContext)
    private var context: EmbraceTraceViewContext
    
    @Environment(\.embraceTraceViewLogger)
    private var logger: EmbraceTraceViewLogger
    
    private let content: () -> Content
    private let name: String
    private let attributes: [String: String]?
    
    /// Creates a new `EmbraceTraceView` that wraps the given content for tracing.
    ///
    /// - Parameters:
    ///   - viewName: The stable identifier used in trace dashboards (e.g., screen or component name).
    ///   - attributes: Optional metadata to associate with all spans created by this view.
    ///   - content: A closure returning the view content to wrap.
    public init(
        _ viewName: String,
        attributes: [String: String]? = nil,
        content: @escaping () -> Content
    ) {
        self.name = viewName
        self.attributes = attributes
        self.content = content
    }
    
    public var body: some View {
        // If tracing is disabled or we lack a valid OTel client, just render content.
        guard let config = logger.config, config.isSwiftUiViewInstrumentationEnabled else {
            return content()
                .onAppear()  // placeholder to satisfy return type
                .onDisappear()
        }
        
        let startTime = Date()
        
        // If no “cycle” span exists for this render tick, create one.
        if context.firstCycleSpan == nil {
            context.firstCycleSpan = logger.cycledSpan(
                name,
                semantics: SpanSemantics.SwiftUIView.cycleName,
                time: startTime,
                parent: nil,
                attributes: attributes
            ) {
                // Reset cycle root after the run loop tick completes
                context.firstCycleSpan = nil
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

        return content()
            .onAppear {
                // Create and end an “appear” span for this view
                logger.cycledSpan(
                    name,
                    semantics: SpanSemantics.SwiftUIView.appearName,
                    parent: context.firstCycleSpan,
                    attributes: attributes
                ) {}
            }
            .onDisappear {
                // Create and end a “disappear” span for this view
                logger.cycledSpan(
                    name,
                    semantics: SpanSemantics.SwiftUIView.disappearName,
                    parent: context.firstCycleSpan,
                    attributes: attributes
                ) {}
            }
    }
}
