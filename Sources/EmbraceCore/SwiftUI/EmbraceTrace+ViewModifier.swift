import SwiftUI

/// Adds EmbraceTrace instrumentation to SwiftUI views.
///
/// This extension provides the `embraceTrace` view modifier, which wraps
/// the view in an `EmbraceTraceView` to emit tracing spans for rendering
/// cycles and body evaluations.
@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6.0, *)
public extension View {
    /// Wraps this view in an EmbraceTraceView to enable tracing.
    ///
    /// - Parameters:
    ///   - viewName: A label for the view used in span naming.
    ///   - attributes: An optional dictionary of metadata to attach to spans.
    /// - Returns: A new view instrumented with EmbraceTrace for performance tracing.
    func embraceTrace(_ viewName: String, attributes: [String: String]? = nil) -> some View {
        EmbraceTraceView(viewName, attributes: attributes) { self }
    }
}
