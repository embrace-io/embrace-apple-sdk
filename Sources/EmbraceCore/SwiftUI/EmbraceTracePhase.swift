import Foundation
import EmbraceCommonInternal
import OpenTelemetryApi
import QuartzCore

@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6.0, *)
final internal class EmbraceTracePhase {
    
    static let shared = EmbraceTracePhase()
    
    private var spanStack: [OpenTelemetryApi.Span] = []
    private var rootSpanStack: [OpenTelemetryApi.Span] = []

    private init() {
        dispatchPrecondition(condition: .onQueue(.main))
    }
    
    deinit {
        dispatchPrecondition(condition: .onQueue(.main))
    }
    
    var isFirstCycle: Bool {
        dispatchPrecondition(condition: .onQueue(.main))
        return rootSpanStack.isEmpty
    }

    func onNextCycle(_ block: @escaping () -> Void) {
        RunLoop.main.perform(inModes: [.common], block: block)
    }
    
    func startSpan(_ name: String, root: Bool, attributes: [String: String]? = nil, _ function: StaticString = #function) -> OpenTelemetryApi.Span? {
        
        dispatchPrecondition(condition: .onQueue(.main))
        
        guard let client = Embrace.client else { return nil }
        
        let sanitizedName = "\(name.lowercased())"

        let builder = client.buildSpan(name: sanitizedName, attributes: attributes ?? [:])
        if root {
            if let parent = rootSpanStack.first {
                builder.setParent(parent)
            }
        } else {
            if let parent = spanStack.last {
                builder.setParent(parent)
            }
        }

        let span = builder.startSpan()
        if root {
            rootSpanStack.append(span)
        } else {
            spanStack.append(span)
        }
        
        return span
    }
    
    func endSpan(_ span: OpenTelemetryApi.Span?, root: Bool, _ function: StaticString = #function) {
        
        dispatchPrecondition(condition: .onQueue(.main))
        
        guard let span else { return }
        
        if root {
            
            guard let index = rootSpanStack.firstIndex(where: { $0.context.spanId == span.context.spanId }) else {
                print("[AC] cannot find root span to end, did you start it with `EmbraceTracePhase.startSpan()`?")
                return
            }
            
            if index != 0 {
                print("[AC] \(span.name) This isn't the first root span")
            }
            
            let poppedSpan = rootSpanStack.remove(at: index)
            span.end()
            
        } else {
            
            guard let index = spanStack.lastIndex(where: { $0.context.spanId == span.context.spanId }) else {
                print("[AC] cannot find span to end, did you start it with `EmbraceTracePhase.startSpan()`?")
                return
            }
            
            if index != spanStack.count-1 {
                print("[AC] \(span.name) This isn't the last span")
            }
            
            let poppedSpan = spanStack.remove(at: index)
            span.end()
            
        }
    }
}
