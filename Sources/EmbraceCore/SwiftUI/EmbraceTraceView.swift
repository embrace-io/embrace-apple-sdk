//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import SwiftUI
import OpenTelemetryApi
#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceSemantics
#endif

/// A SwiftUI view wrapper that provides comprehensive tracing for view performance.
///
/// `EmbraceTraceView` instruments SwiftUI views with detailed performance tracing, capturing:
/// - View initialization and lifecycle timing
/// - Body evaluation performance and frequency
/// - First render cycle measurements
/// - View appearance/disappearance events
///
/// ## Usage
/// ```swift
/// EmbraceTraceView("LoginScreen") {
///     LoginView()
/// }
/// ```
///
/// Or using the view modifier:
/// ```swift
/// LoginView()
///     .embraceTrace("LoginScreen")
/// ```
///
/// ## Performance Impact
/// The tracing overhead is minimal during normal operation:
/// - Span creation: ~0.1ms per span
/// - Body wrapping: ~0.01ms per evaluation
/// - Configuration checks: ~0.001ms per call
///
/// When tracing is disabled via configuration, all operations become no-ops
/// with virtually zero performance impact.
///
/// ## Thread Safety
/// This view is designed for main thread usage only, which aligns with SwiftUI's
/// threading requirements. All tracing operations are automatically performed
/// on the main thread.
@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6.0, *)
public struct EmbraceTraceView<Content: View>: View {
    
    // MARK: - Properties
    
    /// Closure providing the SwiftUI content to be rendered within the trace view
    ///
    /// This closure is captured and called for each body evaluation, allowing
    /// the wrapper to measure the performance of the wrapped content.
    let content: () -> Content
    
    /// Persistent view data that maintains state across SwiftUI re-renders
    ///
    /// Using `@State` ensures that the tracing data survives view updates
    /// and maintains consistent span relationships throughout the view lifecycle.
    @State private var viewData: EmbraceTraceViewData
    
    // MARK: - Lifecycle
    
    /// Creates a new instrumented SwiftUI view wrapper.
    ///
    /// This initializer sets up the tracing infrastructure and begins monitoring
    /// the view lifecycle. The actual span creation is deferred until the view
    /// begins its render cycle to avoid creating spans for views that are never displayed.
    ///
    /// ## View Name Guidelines
    /// - Use descriptive, unique names that identify the view's purpose
    /// - Avoid dynamic content that changes frequently (e.g., user names, timestamps)
    /// - Consider using hierarchical naming for complex UIs (e.g., "Settings.Profile.EditForm")
    ///
    /// ## Attributes Best Practices
    /// - Include stable metadata that helps with filtering and analysis
    /// - Avoid personally identifiable information (PII)
    /// - Consider including view configuration flags or feature toggles
    ///
    /// - Parameters:
    ///   - viewName: A unique identifier for this view used in span naming and analysis.
    ///              Should be stable across app runs and not contain dynamic user data.
    ///   - attributes: Optional metadata dictionary attached to all spans for this view.
    ///                Useful for filtering traces by feature flags, user segments, etc.
    ///   - content: A closure returning the SwiftUI content to be instrumented.
    ///             This closure will be called for each body evaluation.
    ///
    /// - Note: The view data initialization triggers the initial timing measurements
    ///   for the view initialization period.
    public init(
        _ viewName: String,
        attributes: [String: String]? = nil,
        content: @escaping () -> Content
    ) {
        self.content = content
        
        // Initialize the @State property using the underscore syntax to ensure
        // proper SwiftUI state management
        self._viewData = State(
            initialValue: EmbraceTraceViewData(
                name: viewName,
                attributes: attributes
            )
        )
        
        // Begin initialization timing - this measures the time from view
        // initialization until the view first appears on screen
        self.viewData.onViewInit()
    }
    
    // MARK: - View Implementation
    
    /// The instrumented SwiftUI view body.
    ///
    /// This implementation wraps the original content with performance tracing:
    ///
    /// 1. **Body Execution Tracing**: Each call to this computed property creates
    ///    a span measuring the time spent evaluating the wrapped content
    ///
    /// 2. **First Render Special Handling**: The first body evaluation gets
    ///    additional instrumentation to measure the complete first render cycle
    ///
    /// 3. **Lifecycle Event Handling**: Appearance and disappearance events
    ///    are captured to complete the view lifecycle timeline
    ///
    /// ## Performance Considerations
    /// The `onBody` call adds minimal overhead (~0.01ms) to each body evaluation.
    /// This is typically negligible compared to the actual view rendering time.
    ///
    /// ## Span Timeline
    /// ```
    /// init() -> onBody() -> onAppear() -> [user interaction] -> onDisappear()
    ///   |         |           |                                      |
    ///   |         |           +-- Ends "init to appear" span         |
    ///   |         +-- Creates "body execution" span                  |
    ///   +-- Starts "init to appear" span                             +-- Updates counters
    /// ```
    public var body: some View {
        return viewData.onBody {
            content()
        }
        .onAppear {
            viewData.onAppear()
        }
        .onDisappear {
            viewData.onDisappear()
        }
    }
}
