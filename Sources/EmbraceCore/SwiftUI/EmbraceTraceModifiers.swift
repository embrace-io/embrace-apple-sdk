//
//  EmbraceTraceViewModifier.swift
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import SwiftUI

/// A SwiftUI `View` extension that makes it easy to add Embrace performance tracing
/// without changing your existing view hierarchy.
///
/// By applying `.embraceTrace(_:)` to any view, you instruct the SDK to track:
///  - When the view is initialized and its `body` evaluated
///  - Each render cycle (including SwiftUI’s internal optimizations)
///  - Lifecycle events such as `onAppear` and `onDisappear`
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
/// ```
///
/// **Best Practices:**
///  - Choose stable, human-readable names (e.g., screen names or major view components).
///  - Avoid including PII or highly dynamic values in `viewName` or `attributes`.
///  - Focus on performance-sensitive screens and key user interactions.
///  - Skip trivial, static views or views that re-render extremely frequently.
///
/// - Parameters:
///   - viewName: A stable identifier for this view (appears in Embrace trace dashboards).
///   - attributes: Optional metadata (key/value pairs) to enrich trace analysis.
///   - contentComplete: A value that when changed, will flag the View as content complete.
/// - Returns: A new `View` wrapped with Embrace tracing instrumentation.
@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6.0, *)
extension View {
    public func embraceTrace(
        _ viewName: String,
        attributes: [String: String]? = nil
    ) -> some View {
        EmbraceTraceView(
            viewName,
            attributes: attributes
        ) { self }
    }

    public func embraceTrace<V: Equatable>(
        _ viewName: String,
        attributes: [String: String]? = nil,
        contentComplete: V
    ) -> some View {
        EmbraceTraceView(
            viewName,
            attributes: attributes,
            contentComplete: contentComplete
        ) { self }
    }
}

@available(iOS 14, tvOS 14, *)
extension View {

    public func embraceSurface(
        _ viewName: String,
        attributes: [String: String]? = nil
    ) -> some View {
        EmbraceTraceSurfaceView(
            viewName,
            attributes: attributes
        ) { self }
    }
}
