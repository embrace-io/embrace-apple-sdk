import SwiftUI
import OpenTelemetryApi

internal struct EmbraceTraceView<Content: View>: View {
    
    let content: () -> Content
    let name: String
    let attributes: [String: String]?
    let phase = EmbraceTracePhase.shared
    
    init(_ viewName: String, attributes: [String: String]? = nil, content: @escaping () -> Content) {
        self.content = content
        self.name = viewName
        self.attributes = attributes
    }
    
    var body: some View {
        
        // This span is created on the first cycle when the
        // root body that is instrumented is executed, and
        // ends on the next cycle of the run loop.
        if phase.isFirstCycle {
            
            let span = phase.startSpan("emb-sui-view-root-load-\(name)", attributes: attributes)
            phase.onNextCycle {
                phase.endSpan(span)
            }
        }
        
        // This span wraps the actual loading of the content for this View's body.
        let span = phase.startSpan("emb-sui-view-body-\(name)", attributes: attributes)
        defer {
            phase.endSpan(span)
        }
        
        return content()
    }
}
