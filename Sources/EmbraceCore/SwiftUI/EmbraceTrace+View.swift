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
            
            let span = phase.startSpan("VIEW-FC-\(name)", root: true, attributes: attributes)
            phase.onNextCycle {
                phase.endSpan(span, root: true)
            }
        }
        
        // This span wraps the actual loading of the content for this View's body.
        let span = phase.startSpan("VIEW-BODY-\(name)", root: false, attributes: attributes)
        defer {
            phase.endSpan(span, root: false)
        }

        return content()
    }
}
