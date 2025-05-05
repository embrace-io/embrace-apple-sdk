import Foundation
import EmbraceCommonInternal
import OpenTelemetryApi
import QuartzCore

@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6.0, *)
final internal class EmbraceTracePhase {
    
    static let shared = EmbraceTracePhase()
    
    private var spanStack: [OpenTelemetryApi.Span] = []
    
    private var _next: UInt = 0
    private var next: UInt {
        dispatchPrecondition(condition: .onQueue(.main))
        _next += 1
        return _next
    }
    
    private init() {
        dispatchPrecondition(condition: .onQueue(.main))
    }
    
    deinit {
        dispatchPrecondition(condition: .onQueue(.main))
    }
    
    var isFirstCycle: Bool {
        dispatchPrecondition(condition: .onQueue(.main))
        return spanStack.isEmpty
    }
    
    var logPrefix: String {
        Array(repeating: "\t", count: spanStack.count).joined() + "[\(RunLoopTracker.main.debugCycleString)]"
    }
    
    func onNextCycle(_ block: @escaping () -> Void) {
        dispatchPrecondition(condition: .onQueue(.main))
        RunLoopTracker.main.performOnNextCycle(block)
    }
    
    func startSpan(_ name: String, attributes: [String: String]? = nil, _ function: StaticString = #function) -> OpenTelemetryApi.Span? {
        
        dispatchPrecondition(condition: .onQueue(.main))
        
        guard let client = Embrace.client else { return nil }
        
        let sanitizedName = "\(name.lowercased())-\(next)"
        
        //print("\(logPrefix)[AC:START:\(CACurrentMediaTime())] \(function) - \(sanitizedName)")

        let builder = client.buildSpan(name: sanitizedName, attributes: attributes ?? [:])
        if let parent = spanStack.last {
            builder.setParent(parent)
        }
        
        let span = builder.startSpan()
        spanStack.append(span)
        return span
    }
    
    func endSpan(_ span: OpenTelemetryApi.Span?, _ function: StaticString = #function) {
        
        dispatchPrecondition(condition: .onQueue(.main))
        
        guard let span else { return }
        
        guard let index = spanStack.lastIndex(where: { $0.context.spanId == span.context.spanId }) else {
            print("[AC] cannot find span to end, did you start it with `EmbraceTracePhase.startSpan()`?")
            return
        }
        
        if index != spanStack.count-1 {
            //print("[AC] This isn't the last span")
        }
        
        let poppedSpan = spanStack.remove(at: index)
        span.end()
        
        //print("\(logPrefix)[AC:END:\(CACurrentMediaTime())] \(function) - \(span.name)")
    }
}
