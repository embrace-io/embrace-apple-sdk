import Foundation
import QuartzCore

#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceCommonInternal
import EmbraceSemantics
import EmbraceOTelInternal
#endif
import OpenTelemetryApi

/// Manages tracing spans for SwiftUI view instrumentation.
///
/// Provides both one-off spans and cycle-based spans that automatically
/// terminate at the next run loop cycle. Ensures spans are nested correctly
/// and enforces execution on the main thread.
@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6.0, *)
final internal class EmbraceTracePhase {
    
    /// Shared singleton instance used throughout the app for SwiftUI tracing.
    static let shared = EmbraceTracePhase(
        otel: Embrace.client,
        logger: Embrace.logger
    )
    
    /// Initializes a new trace phase manager.
    ///
    /// - Parameters:
    ///   - otel: The OpenTelemetry client used to build and record spans.
    ///   - logger: Internal logger for diagnostic messages.
    /// - Precondition: Must be called on the main thread.
    init(otel: EmbraceOpenTelemetry?, logger: InternalLogger?) {
        dispatchPrecondition(condition: .onQueue(.main))
        self.otel = otel
        self.logger = logger
    }
    
    /// Cleans up and validates that no pending spans remain.
    /// - Precondition: Must be called on the main thread.
    deinit {
        dispatchPrecondition(condition: .onQueue(.main))
    }
    
    /// Returns `true` if no cycle-based spans are currently open.
    ///
    /// Indicates the first instrumentation cycle of a view body.
    var isFirstCycle: Bool {
        dispatchPrecondition(condition: .onQueue(.main))
        return cycleSpans.isEmpty
    }
    
    var isFirstRender: Bool {
        dispatchPrecondition(condition: .onQueue(.main))
        return spans.isEmpty
    }
    
    /// Begins a synchronous span that must be explicitly ended.
    ///
    /// - Parameters:
    ///   - name: A descriptive name for the span.
    ///   - attributes: Optional metadata to attach to the span.
    ///   - function: The calling function for diagnostics (defaults to `#function`).
    /// - Returns: The started span, or `nil` if tracing is unavailable.
    func startSpan(_ name: String, attributes: [String: String]? = nil, _ function: StaticString = #function) -> OpenTelemetryApi.Span? {
        startSpan(
            name,
            isCycle: false,
            attributes: attributes,
            function
        )
    }
    
    /// Ends a span started via `startSpan`.
    ///
    /// - Parameters:
    ///   - span: The span to end. Logs an error if `nil` or mismatched.
    ///   - function: The calling function for diagnostics.
    func endSpan(_ span: OpenTelemetryApi.Span?, _ function: StaticString = #function) {
        endSpan(span, isCycle: false)
    }
    
    /// Starts a span that automatically ends on the next run loop cycle.
    ///
    /// - Parameters:
    ///   - name: A descriptive name for the cycle span.
    ///   - attributes: Optional metadata for the span.
    ///   - function: The calling function for diagnostics.
    func cycledSpan(_ name: String, attributes: [String: String]? = nil, _ function: StaticString = #function) {
        let span = startSpan(
            name,
            isCycle: true,
            attributes: attributes,
            function
        )
        onNextCycle { [self] in
            endSpan(span, isCycle: true)
        }
    }
    
    /// The OpenTelemetry client used to create spans.
    internal let otel: EmbraceOpenTelemetry?
    /// Logger for internal tracing diagnostics and errors.
    internal let logger: InternalLogger?

    /// LIFO storage for active non-cycled spans.
    private var spans: Stack = Stack()
    /// FIFO storage for active cycle-based spans.
    private var cycleSpans: Queue = Queue()
}

// MARK: - Private Span Management

fileprivate extension EmbraceTracePhase {
    
    /// Schedules a block to run on the main run loop in `.common` modes.
    func onNextCycle(_ block: @escaping () -> Void) {
        RunLoop.main.perform(inModes: [.common], block: block)
    }
    
    /// Underlying implementation for starting both cycled and non-cycled spans.
    ///
    /// - Parameters:
    ///   - name: Span name.
    ///   - isCycle: Whether the span should auto-terminate on next loop.
    ///   - attributes: Metadata for the span.
    ///   - function: Calling function for diagnostics.
    /// - Returns: The created span, or `nil` if tracing unavailable.
    func startSpan(_ name: String, isCycle: Bool, attributes: [String: String]? = nil, _ function: StaticString = #function) -> OpenTelemetryApi.Span? {
        
        dispatchPrecondition(condition: .onQueue(.main))
        guard let client = otel else {
            logger?.debug("OTel client is unavailable, we won't be logging from EmbraceTracePhase.")
            return nil
        }

        let builder = client.buildSpan(
            name: name,
            type: .performance,
            attributes: attributes ?? [:],
            autoTerminationCode: nil
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
        
        #if DEBUG
        print("[SPAN:START] id: \(span.context.spanId.hexString) name: \(span.name), time: \(CFAbsoluteTimeGetCurrent())")
        #endif

        return span
    }
    
    /// Underlying implementation to end a span and validate stack consistency.
    ///
    /// - Parameters:
    ///   - span: The span to end.
    ///   - isCycle: Indicates if the span was a cycle span.
    ///   - function: Calling function for diagnostics.
    func endSpan(_ span: OpenTelemetryApi.Span?, isCycle: Bool, _ function: StaticString = #function) {
        
        dispatchPrecondition(condition: .onQueue(.main))
        guard let span else {
            return
        }
        
        let storage: LinearCollection = if isCycle { cycleSpans } else { spans }
        guard let found = storage.peek() else {
            logger?.error("Span cache is empty, are you sure you created this span using `startSpan()`?")
            return
        }
        
        guard found.context.spanId == span.context.spanId else {
            logger?.error("No span equivalent to this span found in cache, did you create this span using `startSpan()`?")
            return
        }
        
        if let sp = storage.pop() {
            sp.end()

            #if DEBUG
            print("[SPAN:END] id: \(sp.context.spanId.hexString) name: \(sp.name), time: \(CFAbsoluteTimeGetCurrent())")
            #endif
        }
        
    }
}

/// Protocol for simple span storage collections (stack or queue).
fileprivate protocol LinearCollection {
    func push(_ value: Span)
    func pop() -> Span?
    func peek() -> Span?
    var isEmpty: Bool { get }
}

/// Default implementation for `isEmpty` based on `peek()`.
fileprivate extension LinearCollection {
    var isEmpty: Bool { peek() == nil }
}

/// FIFO queue implementation for cycle-based spans.
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

/// LIFO stack implementation for non-cycle spans.
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
