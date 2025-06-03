//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import SwiftUI

/// SwiftUI View extension that provides convenient access to Embrace tracing functionality.
///
/// This extension adds the `embraceTrace` view modifier to all SwiftUI views,
/// allowing for easy integration of performance tracing without changing the
/// existing view hierarchy structure.
///
/// ## Usage Examples
///
/// ### Basic Usage
/// ```swift
/// Text("Hello World")
///     .embraceTrace("GreetingText")
/// ```
///
/// ### With Custom Attributes
/// ```swift
/// UserProfileView(user: currentUser)
///     .embraceTrace("UserProfile", attributes: [
///         "user_type": user.type,
///         "premium_user": user.isPremium ? "true" : "false"
///     ])
/// ```
///
/// ### Complex View Hierarchies
/// ```swift
/// VStack {
///     HeaderView()
///         .embraceTrace("Header")
///
///     ContentView()
///         .embraceTrace("MainContent")
///
///     FooterView()
///         .embraceTrace("Footer")
/// }
/// .embraceTrace("MainScreen")
/// ```
///
/// ## Integration Patterns
///
/// ### Feature Flag Integration
/// ```swift
/// extension View {
///     func conditionalTracing(_ viewName: String) -> some View {
///         if FeatureFlags.isTracingEnabled {
///             return self.embraceTrace(viewName)
///         } else {
///             return self
///         }
///     }
/// }
/// ```
///
/// ### Environment-Based Naming
/// ```swift
/// struct TracedView: View {
///     @Environment(\.screenName) private var screenName
///
///     var body: some View {
///         MyView()
///             .embraceTrace(screenName)
///     }
/// }
/// ```
@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6.0, *)
public extension View {
    
    /// Wraps this view with Embrace performance tracing instrumentation.
    ///
    /// This modifier creates an `EmbraceTraceView` wrapper around the current view,
    /// enabling comprehensive performance monitoring including:
    /// - View initialization timing
    /// - Body evaluation performance
    /// - First render cycle measurements
    /// - Lifecycle event tracking
    ///
    /// ## Performance Impact
    /// - **Enabled**: Adds ~0.01ms overhead per body evaluation
    /// - **Disabled**: Nearly zero overhead (single configuration check)
    /// - **Memory**: ~200 bytes per traced view instance
    ///
    /// ## Best Practices
    ///
    /// ### View Naming
    /// - Use consistent, descriptive names that identify the view's purpose
    /// - Avoid including dynamic user data or timestamps in names
    /// - Consider using dot notation for hierarchical organization
    ///
    /// ### Attribute Usage
    /// - Include relevant metadata for filtering and analysis
    /// - Avoid personally identifiable information (PII)
    /// - Use consistent attribute keys across similar views
    ///
    /// ### When to Trace
    /// - Key user interface screens and components
    /// - Views with known or suspected performance issues
    /// - Complex views with multiple child components
    /// - Views in critical user flows (login, checkout, etc.)
    ///
    /// ### When NOT to Trace
    /// - Simple static views (single Text or Image views)
    /// - Views that render very frequently (scroll indicators, animations)
    /// - Internal implementation details not visible to users
    ///
    /// - Parameters:
    ///   - viewName: A stable, descriptive identifier for the view. This name
    ///              appears in trace analysis tools and should be consistent
    ///              across app runs. Avoid including dynamic content.
    ///   - attributes: Optional metadata to attach to all spans created for
    ///                this view. Useful for categorizing traces by feature,
    ///                user segment, or configuration state.
    ///
    /// - Returns: A new view that wraps the original with tracing instrumentation.
    ///           The returned view maintains the same interface and behavior as
    ///           the original while adding performance monitoring.
    ///
    /// ## Example Trace Output
    /// ```
    /// [LoginScreen]-view-load                    (2.3s)
    /// ├── [LoginScreen]-init-to-appear          (1.1s)
    /// ├── [LoginScreen]-first-render-cycle      (0.8s)
    /// └── [LoginScreen]-body-execution          (0.02s)
    /// ```
    func embraceTrace(
        _ viewName: String,
        attributes: [String: String]? = nil
    ) -> some View {
        EmbraceTraceView(viewName, attributes: attributes) { self }
    }
}
