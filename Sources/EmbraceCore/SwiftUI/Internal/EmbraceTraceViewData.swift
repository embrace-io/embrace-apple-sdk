import SwiftUI
import OpenTelemetryApi
#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceSemantics
#endif

@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6.0, *)
internal class EmbraceTraceViewData {
    
    let phase: EmbraceTraceViewLogger = EmbraceTraceViewLogger.shared
    let name: String
    let attributes: [String: String]?
    var id: String {
        let ptr = Unmanaged.passUnretained(self).toOpaque()
        return String(format: "%p", Int(bitPattern: ptr))
    }
    
    // Accounting for spans
    private var spans: [Span] = []
    
    // add a span that is already started
    // also starts the root span if it isn't started
    func add(_ span: Span?) {
        if let span {
            startRootSpanIfNeeded()
            spans.append(span)
        }
    }
    
    // removes a span that is already ended
    // also removes the root span if no other spans are open
    func remove(_ span: Span?, errorCode: SpanErrorCode? = nil) {
        if let span, let index = spans.firstIndex(where: { span.context.spanId.hexString == $0.context.spanId.hexString}) {
            spans.remove(at: index)
            if spans.isEmpty, rootSpan != nil {
                phase.endSpan(rootSpan, errorCode: errorCode)
                rootSpan = nil
            }
        }
    }
    
    // starts the root span if it isn't started
    private func startRootSpanIfNeeded() {
        guard rootSpan == nil else { return }

        rootSpan = phase.startSpan(
            name,
            semantics: SpanSemantics.SwiftUIView.viewLoadName,
            time: nil,
            attributes: self.attributes
        )
    }
    
    private var initToAppearSpan: Span? = nil
    private var rootSpan: Span? = nil
    
    struct Counters {
        var initialized: UInt = 0
        var bodyCount: UInt = 0
        var appear: UInt = 0
        var disappear: UInt = 0
    }
    var counters: Counters = Counters()
    
    init(name: String, attributes: [String: String]?) {
        self.name = name
        self.attributes = attributes
    }
    
    deinit {
        spans.forEach { phase.endSpan($0, errorCode: .unknown) }
        spans.removeAll()
        phase.endSpan(rootSpan, errorCode: .unknown)
        rootSpan = nil
    }
}

extension EmbraceTraceViewData {
    func onAppear() {
        counters.appear += 1
        phase.endSpan(initToAppearSpan)
        remove(initToAppearSpan)
        initToAppearSpan = nil
    }
    
    func onDisappear() {
        counters.disappear += 1
    }
    
    func onBody<C>(_ body: () -> C ) -> C {
        
        let time = Date()
        
        counters.bodyCount += 1
        
        // first render of the body
        if counters.bodyCount == 1 {
            // First body means first render cycle
            if let span = phase.startSpan(
                name,
                semantics: SpanSemantics.SwiftUIView.firstRenderCycleName,
                time: time,
                parent: rootSpan,
                attributes: attributes)
            {
                add(span)
                RunLoop.main.perform(inModes: [.common]) { [self] in
                    phase.endSpan(span)
                    remove(span)
                }
            }
        }

        // first and subsequent renders of the body
        let span = phase.startSpan(
            name,
            semantics: SpanSemantics.SwiftUIView.bodyExecutionName,
            time: time,
            parent: rootSpan,
            attributes: attributes
        )
        add(span)
        defer {
            phase.endSpan(span)
            remove(span)
        }
        return body()
    }
    
    func onViewInit() {
        counters.initialized += 1
        guard counters.initialized == 1 else {
            return
        }

        // add the init to on appear span
        initToAppearSpan = phase.startSpan(
            name,
            semantics: SpanSemantics.SwiftUIView.initToOnAppearName,
            time: nil,
            parent: rootSpan,
            attributes: attributes
        )
        add(initToAppearSpan)
    }
}
