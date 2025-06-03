import SwiftUI
import OpenTelemetryApi
#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceSemantics
#endif

/// A SwiftUI view wrapper that integrates with EmbraceTrace and OpenTelemetry to instrument view rendering cycles.
/// It measures the first render cycle and wraps the view's body evaluation in tracing spans.
@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6.0, *)
public struct EmbraceTraceView<Content: View>: View {
    
    /// Closure providing the SwiftUI content to be rendered within the trace view.
    let content: () -> Content
    /// View Data we want persisted accross renders
    @State private var viewData: EmbraceTraceViewData
    
    /// Creates a new `EmbraceTraceView`.
    /// - Parameters:
    ///   - viewName: A unique name used to identify the view in tracing spans.
    ///   - attributes: An optional dictionary of metadata to attach to spans.
    ///   - content: A closure returning the view content to be instrumented.
    public init(_ viewName: String, attributes: [String: String]? = nil, content: @escaping () -> Content) {
        self.content = content
        
        self._viewData = State(
            initialValue: EmbraceTraceViewData(
                name: viewName,
                attributes: attributes
            )
        )
        self.viewData.onViewInit()
    }
    
    /// The SwiftUI view body, instrumented with:
    /// 1. A span on the first run loop cycle around the view's initialization.
    /// 2. A span wrapping the content evaluation for each body render.
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



