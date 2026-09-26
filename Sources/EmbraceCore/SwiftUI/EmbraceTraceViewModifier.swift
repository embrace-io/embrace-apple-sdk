//
//  EmbraceTraceViewModifier.swift
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import SwiftUI

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

/// A SwiftUI `View` extension that makes it easy to add Embrace performance tracing
/// without changing your existing view hierarchy.
///
/// By applying `.embraceTrace(_:)` to any view, you instruct the SDK to track:
///  - How long the view took to first render, from initialization to `onAppear`
///  - Lifecycle events such as `onAppear` and `onDisappear`
///  - Optionally, each `body` evaluation and the render cycle grouping them
///    (opt in with `trackBodyEvaluations`)
///
/// When tracing is disabled, this modifier incurs almost zero overhead.
///
/// **Usage Examples:**
/// ```swift
/// // Simple trace with just a name
/// Text("Hello World")
///     .embraceTrace("GreetingText")
///
/// // Trace with custom attributes
/// UserProfileView(user: user)
///     .embraceTrace("UserProfile", attributes: [
///         "user_type": user.type,
///         "is_premium": user.isPremium ? "true" : "false"
///     ])
///
/// // Opt in to body evaluation spans while debugging a specific view
/// SlowListView()
///     .embraceTrace("SlowList", trackBodyEvaluations: true)
/// ```
///
/// **Best Practices:**
///  - Choose stable, human-readable names (e.g., screen names or major view components).
///  - Avoid including PII or highly dynamic values in `viewName` or `attributes`.
///  - Focus on performance-sensitive screens and key user interactions.
///  - Skip trivial, static views or views that re-render extremely frequently.
///  - Leave `trackBodyEvaluations` off outside of active investigation: SwiftUI evaluates `body`
///    often enough that the spans crowd out the signal (an animation can emit thousands a minute).
///
/// - Parameters:
///   - viewName: A stable identifier for this view (appears in Embrace trace dashboards).
///   - attributes: Optional metadata (key/value pairs) to enrich trace analysis.
///   - trackBodyEvaluations: Whether to emit a span per `body` evaluation, plus the `render-loop`
///     span grouping them. Defaults to `false`.
///   - contentComplete: A value that when changed, will flag the View as content complete.
/// - Returns: A new `View` wrapped with Embrace tracing instrumentation.
@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6.0, *)
extension View {
    public func embraceTrace(
        _ viewName: String,
        attributes: EmbraceAttributes? = nil,
        trackBodyEvaluations: Bool = false
    ) -> some View {
        EmbraceTraceView(
            viewName,
            attributes: attributes,
            trackBodyEvaluations: trackBodyEvaluations
        ) { self }
    }

    /// Wraps the view in an `EmbraceTraceView` that ends the trace when `contentComplete` changes.
    /// - Parameters:
    ///   - viewName: Name used for the generated trace.
    ///   - attributes: Attributes to set on the trace.
    ///   - trackBodyEvaluations: Whether to emit a span per `body` evaluation, plus the `render-loop`
    ///     span grouping them. Defaults to `false`.
    ///   - contentComplete: Value whose change signals that the content has finished loading.
    public func embraceTrace<V: Equatable>(
        _ viewName: String,
        attributes: EmbraceAttributes? = nil,
        trackBodyEvaluations: Bool = false,
        contentComplete: V
    ) -> some View {
        EmbraceTraceView(
            viewName,
            attributes: attributes,
            trackBodyEvaluations: trackBodyEvaluations,
            contentComplete: contentComplete
        ) { self }
    }
}
