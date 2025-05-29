import SwiftUI
import OpenTelemetryApi

/// A SwiftUI view wrapper that integrates with EmbraceTrace and OpenTelemetry to instrument view rendering cycles.
/// It measures the first render cycle and wraps the view's body evaluation in tracing spans.
public struct EmbraceTraceView<Content: View>: View {
    
    /// Closure providing the SwiftUI content to be rendered within the trace view.
    let content: () -> Content
    /// A label for this view used in span naming.
    let name: String
    /// Optional metadata attributes to attach to the created tracing spans.
    let attributes: [String: String]?
    /// Shared manager that controls span lifecycle and cycle detection.
    let phase = EmbraceTracePhase.shared
    
    /// Creates a new `EmbraceTraceView`.
    /// - Parameters:
    ///   - viewName: A unique name used to identify the view in tracing spans.
    ///   - attributes: An optional dictionary of metadata to attach to spans.
    ///   - content: A closure returning the view content to be instrumented.
    public init(_ viewName: String, attributes: [String: String]? = nil, content: @escaping () -> Content) {
        self.content = content
        self.name = viewName.filter { $0.isNumber || $0.isLetter }
        self.attributes = attributes
    }
    
    /// The SwiftUI view body, instrumented with:
    /// 1. A span on the first run loop cycle around the view's initialization.
    /// 2. A span wrapping the content evaluation for each body render.
    public var body: some View {
        
        if phase.isFirstCycle {
            /// Emit a tracing span for the first render cycle of this view.
            // TODO: name this correctly
            phase.cycledSpan("emb-sui-[\(name)]-first-render-cycle", attributes: attributes)
        }
        
        var firstRenderPhaseSpan: Span? = nil
        if phase.isFirstRender {
            /// Emit a tracing span for the first render of this view.
            firstRenderPhaseSpan = phase.startSpan("emb-sui-[\(name)]-first-body-render", attributes: attributes)
        }
        
        /// Start a span around the body evaluation of the view.
        // TODO: name this correctly
        let span = phase.startSpan("emb-sui-[\(name)]-body-execution", attributes: attributes)
        /// End the body evaluation span when the view content finishes loading.
        defer {
            phase.endSpan(span)
        }
        
        return content()
            .onAppear {
                phase.endSpan(firstRenderPhaseSpan)
            }
    }
}
