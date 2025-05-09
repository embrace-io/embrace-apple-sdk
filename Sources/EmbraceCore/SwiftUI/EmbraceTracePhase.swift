import Foundation
import EmbraceCommonInternal
import OpenTelemetryApi
import QuartzCore

/// The `EmbraceTracePhase` class keeps track of the state
/// of spans for SwiftUI tracing View Modifiers and Views.
/// There are 2 types of spans.
/// 1. Normal spans that you start and end in a linear manner (_spans_).
/// 2. Cycle spans which you start with `cycledSpan`, and they will be
/// ended automatically on the next cycle of the run loop.
@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6.0, *)
final internal class EmbraceTracePhase {
    
    static let shared = EmbraceTracePhase()
    
    private init() {
        dispatchPrecondition(condition: .onQueue(.main))
    }
    
    deinit {
        dispatchPrecondition(condition: .onQueue(.main))
    }
    
    /// Determines if there are any cycled spans currently in progress.
    var isFirstCycle: Bool {
        dispatchPrecondition(condition: .onQueue(.main))
        return cycleSpans.isEmpty
    }
    
    /// Starts a _Span_ which must then be passed to `endSpan()` to be complete it.
    func startSpan(_ name: String, attributes: [String: String]? = nil, _ function: StaticString = #function) -> OpenTelemetryApi.Span? {
        startSpan(
            name,
            isCycle: false,
            attributes: attributes,
            function
        )
    }
    
    /// Ends a _Span_ that was started by `startSpan()`.
    func endSpan(_ span: OpenTelemetryApi.Span?, _ function: StaticString = #function) {
        endSpan(span, isCycle: false)
    }
    
    /// Starts a _Span_, and completes it automatically on the next iteration of the run loop.
    func cycledSpan(_ name: String, attributes: [String: String]? = nil, _ function: StaticString = #function) {
        let span = startSpan(
            name,
            isCycle: true,
            attributes: attributes,
            function
        )
        onNextCycle {
            span?
                .end()
        }
    }
    
    private var spans: Stack = Stack()
    private var cycleSpans: Queue = Queue()
}

// MARK: - Private Trace Phase Routines

fileprivate extension EmbraceTracePhase {
    
    func onNextCycle(_ block: @escaping () -> Void) {
        RunLoop.main.perform(inModes: [.common], block: block)
    }
    
    func startSpan(_ name: String, isCycle: Bool, attributes: [String: String]? = nil, _ function: StaticString = #function) -> OpenTelemetryApi.Span? {
        
        dispatchPrecondition(condition: .onQueue(.main))
        guard let client = Embrace.client else { return nil }
        
        // TODO: Figure out how we name things
        let sanitizedName = "\(name.lowercased())"
        
        let builder = client.buildSpan(
            name: sanitizedName,
            // TODO: Is this span type ok? This needs to move to the semnatics module.
            // I think special cases don;t show in the UI, so removing this for now.
            //type: SpanType(performance: "sui_view"),
            attributes: attributes ?? [:]
        )
        
        // get the right storage for this span
        let storage: LinearCollection = if isCycle { cycleSpans } else { spans }
        
        // This simply sets the new span parent to
        // 1. the storage type current span if there is one.
        // 2. The current cycled storage span if this span isn't cycled.
        if let parent = storage.peek() {
            
            // if this storage has spans already,
            // just make the current one this spans parent.
            builder.setParent(parent)
            
        } else if !isCycle, let parent = cycleSpans.peek() {
            
            // if this isn't a cycled span and
            // cycled spans are open, then make that the parent.
            builder.setParent(parent)
        }
        
        let span = builder.startSpan()
        storage.push(span)
        
        return span
    }
    
    func endSpan(_ span: OpenTelemetryApi.Span?, isCycle: Bool, _ function: StaticString = #function) {
        
        dispatchPrecondition(condition: .onQueue(.main))
        guard let span else { return }
        
        let storage: LinearCollection = if isCycle { cycleSpans } else { spans }
        guard let found = storage.peek() else {
            // TODO: Log some relevant stuff here
            return
        }
        
        guard found.context.spanId == span.context.spanId else {
            // TODO: Log some relevant stuff here
            return
        }
        
        storage.pop()?.end()
    }
}

// MARK: - Specialized Collections

// These all simply having a Queue and Stack
// respond to the exact protocol.

fileprivate protocol LinearCollection {
    func push(_ value: Span)
    func pop() -> Span?
    func peek() -> Span?
    var isEmpty: Bool { get }
}

fileprivate extension LinearCollection {
    var isEmpty: Bool { peek() == nil }
}

fileprivate class Queue: LinearCollection {
    var storage: [Span] = []
    func pop() -> Span? {
        guard let first = storage.first else {
            return nil
        }
        storage.removeFirst()
        return first
    }
    func push(_ value: Span) {
        storage.append(value)
    }
    func peek() -> Span? { storage.first }
}

fileprivate class Stack: LinearCollection {
    var storage: [Span] = []
    func pop() -> Span? {
        storage.popLast()
    }
    func push(_ value: Span) {
        storage.append(value)
    }
    func peek() -> Span? { storage.last }
}
