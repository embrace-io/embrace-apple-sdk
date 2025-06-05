//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import SwiftUI
import OpenTelemetryApi
#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceSemantics
#endif

/// Internal data model that manages the lifecycle and state of SwiftUI view tracing.
///
/// This class is responsible for:
/// - Managing spans for view lifecycle events
/// - Tracking view render cycles and performance metrics
/// - Coordinating parent-child span relationships
/// - Providing safe cleanup of tracing resources
///
/// ## Span Hierarchy
/// ```
/// Root Span (view load)
/// ├── Init to Appear Span
/// ├── First Render Cycle Span (first body evaluation only)
/// └── Body Execution Spans (every body evaluation)
/// ```
///
/// ## Thread Safety
/// This class is designed to be used exclusively on the main thread and relies on
/// `EmbraceTraceViewLogger` for thread safety enforcement.
@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6.0, *)
internal class EmbraceTraceViewData {
    
    // MARK: - Public Properties
    
    /// The shared logger instance used for span management
    let logger: EmbraceTraceViewLogger = EmbraceTraceViewLogger.shared
    
    /// The name identifier for this view, used in span naming
    let name: String
    
    /// Optional attributes to attach to all spans created for this view
    let attributes: [String: String]?
    
    /// Unique identifier for this view data instance
    /// - Note: Uses memory address for uniqueness across view instances
    var id: String {
        let ptr = Unmanaged.passUnretained(self).toOpaque()
        return String(format: "%p", Int(bitPattern: ptr))
    }
    
    // MARK: - Private Properties
    
    /// Active child spans that are currently running
    /// - Note: Does not include the root span
    private var spans: [Span] = []
    
    /// The root span that represents the overall view lifecycle
    /// - Note: Created lazily when the first child span is added
    private var rootSpan: Span? = nil
    
    private var onAppearBlocks: [String: () -> Void] = [:]
    private var onDisappearBlocks: [String: () -> Void] = [:]
    private var onBodyBlocks: [String: () -> Void] = [:]
    
    private var inSession: Bool = false
    private var sessionObservers: [Any] = []
    
    // MARK: - Performance Counters
    
    /// Performance and lifecycle counters for debugging and metrics
    struct Counters {
        /// Number of times the view has been initialized
        var initialized: UInt = 0
        
        /// Number of times the view body has been evaluated
        var bodyCount: UInt = 0
        
        /// Number of times the view has appeared
        var appear: UInt = 0
        
        /// Number of times the view has disappeared
        var disappear: UInt = 0
    }
    
    /// Current counter values for this view instance
    var counters: Counters = Counters()
    
    // MARK: - Lifecycle
    
    /// Initializes a new view data instance.
    ///
    /// - Parameters:
    ///   - name: The identifier name for the view
    ///   - attributes: Optional metadata to attach to spans
    ///
    /// - Note: Does not create any spans immediately - spans are created lazily
    ///   when view lifecycle events occur.
    init(name: String, attributes: [String: String]?) {
        self.name = name
        self.attributes = attributes
        self.inSession = logger.sessionId != nil
        
        sessionObservers.append(
            NotificationCenter.default.addObserver(
                forName: .embraceSessionDidStart,
                object: nil,
                queue: nil)
            { [weak self] _ in
                self?.sessionDidStart()
            }
        )
        
        sessionObservers.append(
            NotificationCenter.default.addObserver(
                forName: .embraceSessionWillEnd,
                object: nil,
                queue: nil)
            { [weak self] _ in
                self?.sessionWillEnd()
            }
        )
    }
    
    /// Cleanup method that ensures all spans are properly ended.
    ///
    /// This method handles cleanup for edge cases where spans might still be active
    /// when the view is deallocated, which can happen during:
    /// - Navigation transitions
    /// - App backgrounding
    /// - Unexpected view hierarchy changes
    deinit {
        sessionObservers.forEach {
            NotificationCenter.default.removeObserver($0)
        }
        endAllSpans()
    }
}

// MARK: - Session Management

extension EmbraceTraceViewData {
 
    func sessionDidStart() {
        inSession = true
    }
    
    func sessionWillEnd() {
        inSession = false
        endAllSpans()
    }
    
    func endAllSpans() {
        // Clean up any remaining active spans
        spans.forEach { logger.endSpan($0, errorCode: .unknown) }
        spans.removeAll()
        
        // Clean up root span if it exists
        logger.endSpan(rootSpan, errorCode: .unknown)
        rootSpan = nil
    }
}

// MARK: - Span Management

extension EmbraceTraceViewData {
    
    /// Adds a new active span to the tracking list.
    ///
    /// This method:
    /// 1. Ensures the root span is created if it doesn't exist
    /// 2. Adds the span to the active spans list for lifecycle tracking
    ///
    /// - Parameter span: The span to add (ignored if nil)
    ///
    /// - Note: This method should only be called with spans that are already started
    func _add(make rootIfNeeded: Bool = true, _ block: () -> Span?) -> Span? {
        guard inSession else {
            print("not currently in a session")
            return nil
        }
        
        if rootIfNeeded {
            startRootSpanIfNeeded()
        } else if rootSpan == nil {
            print("root span == nil but asked to not create it")
        }
        guard let span = block() else {
            return nil
        }
        spans.append(span)
        return span
    }
    
    /// Removes a span from the active tracking list and handles root span cleanup.
    ///
    /// This method:
    /// 1. Finds and removes the specified span from the active list
    /// 2. If no spans remain active, ends and cleans up the root span
    /// 3. Propagates any error codes to the appropriate spans
    ///
    /// - Parameters:
    ///   - span: The span to remove (ignored if nil)
    ///   - errorCode: Optional error code to record on the root span
    ///
    /// - Note: This method should only be called with spans that are already ended
    func _remove(_ span: Span?, time: Date? = nil, errorCode: SpanErrorCode? = nil) {
        guard let span else { return }
        
        logger.endSpan(span, time: time, errorCode: errorCode)
        
        // Find and remove the span by comparing span IDs
        if let index = spans.firstIndex(where: { span.context.spanId.hexString == $0.context.spanId.hexString}) {
            spans.remove(at: index)
            
            // If this was the last active span, clean up the root span
            if spans.isEmpty, rootSpan != nil {
                logger.endSpan(rootSpan, errorCode: errorCode)
                rootSpan = nil
            }
        }
    }
    
    /// Creates the root span if it doesn't already exist.
    ///
    /// The root span represents the overall view lifecycle and serves as the parent
    /// for all other spans created for this view. It's created lazily to ensure
    /// we only create spans for views that actually have tracing activity.
    ///
    /// - Note: This method is safe to call multiple times - it will only create
    ///   the root span on the first call.
    private func startRootSpanIfNeeded() {
        guard rootSpan == nil else { return }
        
        guard inSession else {
            print("not currently in a session")
            return
        }
        
        rootSpan = logger.startSpan(
            name,
            semantics: SpanSemantics.SwiftUIView.viewLoadName,
            time: nil,
            attributes: attributes
        )
    }
}

// MARK: - SwiftUI Lifecycle Events

extension EmbraceTraceViewData {
    
    /// Handles the SwiftUI `onAppear` lifecycle event.
    ///
    /// This method:
    /// 1. Increments the appear counter for metrics
    /// 2. Ends the "init to appear" span that measures initialization time
    /// 3. Cleans up the init span from active tracking
    ///
    /// - Note: Can be called multiple times if the view appears/disappears repeatedly
    func onAppear() {
        counters.appear += 1
        
        // Start an appear span, and end
        // it after the next run loop to ensure we
        // get all other appearances within it
        let span = _add(make: false) {
            logger.startSpan(
                name,
                semantics: SpanSemantics.SwiftUIView.onAppearName,
                time: nil,
                attributes: attributes
            )
        }
        if let span {
            RunLoop.main.perform(inModes: [.common]) { [weak self] in
                self?._remove(span)
            }
        }

        let blocks = Array(onAppearBlocks.values)
        blocks.forEach { $0() }
    }
    
    func addOnAppearBlock(_ action: @escaping () -> Void) -> String {
        let id = UUID().uuidString
        onAppearBlocks[id] = action
        return id
    }
    
    func removeOnAppearBlock(_ id: String) {
        onAppearBlocks.removeValue(forKey: id)
    }
    
    /// Handles the SwiftUI `onDisappear` lifecycle event.
    ///
    /// Currently this only updates metrics counters. Future implementations
    /// might add spans for measuring time spent visible or cleanup operations.
    func onDisappear() {
        counters.disappear += 1
        
        // Start a disappear span, and end
        // it after the next run loop to ensure we
        // get all other appearances within it
        let span = _add(make: false) {
            logger.startSpan(
                name,
                semantics: SpanSemantics.SwiftUIView.onDisappearName,
                time: nil,
                attributes: attributes
            )
        }
        if let span {
            RunLoop.main.perform(inModes: [.common]) { [weak self] in
                self?._remove(span)
            }
        }
        
        let blocks = Array(onDisappearBlocks.values)
        blocks.forEach { $0() }
    }
    
    func addOnDisappearBlock(_ action: @escaping () -> Void) -> String {
        let id = UUID().uuidString
        onDisappearBlocks[id] = action
        return id
    }
    
    func removeOnDisappearBlock(_ id: String) {
        onDisappearBlocks.removeValue(forKey: id)
    }
    
    /// Instruments the SwiftUI view body evaluation with performance tracing.
    ///
    /// This method wraps the view's body computation with tracing spans to measure:
    /// - First render cycle performance (one-time span)
    /// - Individual body evaluation performance (every call)
    ///
    /// ## Span Creation
    /// - **First Body Evaluation**: Creates a "first render cycle" span that ends on the next run loop
    /// - **Every Evaluation**: Creates a "body execution" span that ends immediately after the body returns
    ///
    /// - Parameter body: The closure containing the view's body computation
    /// - Returns: The result of executing the body closure
    ///
    /// - Note: The first render span is ended asynchronously to capture the complete
    ///   first render cycle including any layout and drawing operations.
    func onBody<C>(_ body: () -> C ) -> C {
        let time = Date()
        counters.bodyCount += 1
        
        // Create a span for this specific body evaluation
        let span = _add {
            logger.startSpan(
                name,
                semantics: SpanSemantics.SwiftUIView.bodyExecutionName,
                time: time,
                parent: rootSpan,
                attributes: attributes
            )
        }

        // Ensure the span is ended when this method returns
        defer {
            _remove(span)

            // run body bloks
            let blocks = Array(onBodyBlocks.values)
            blocks.forEach { $0() }
        }
        
        #if DEBUG
        if Bool.random() {
            Thread.sleep(forTimeInterval: TimeInterval.random(in: 0...2))
        }
        #endif
        
        return body()
    }
    
    func addOnBodyBlock(_ action: @escaping () -> Void) -> String {
        let id = UUID().uuidString
        onBodyBlocks[id] = action
        return id
    }
    
    func removeOnBodyBlock(_ id: String) {
        onBodyBlocks.removeValue(forKey: id)
    }
    
    /// Handles view initialization and starts timing the initialization period.
    ///
    /// This method:
    /// 1. Increments the initialization counter
    /// 2. Starts a span to measure time from init to first appearance (first init only)
    /// 3. Ensures we only perform initialization tracing once per view instance
    ///
    /// - Note: The init-to-appear span helps identify views that are initialized
    ///   but never displayed, which can indicate performance issues or unused views.
    func onViewInit() {
        counters.initialized += 1

        // Start timing how long it takes from init to first appearance
        var span = _add {
            logger.startSpan(
                name,
                semantics: SpanSemantics.SwiftUIView.initToBodyName,
                time: nil,
                parent: rootSpan,
                attributes: attributes
            )
        }
        guard span != nil else {
            return
        }

        // make sure we remove this on appear,
        var appearedDuringWaitAfterOnBody: Bool = false
        var onAppearId: String?  = nil
        onAppearId = addOnAppearBlock {
            [weak self] in
            guard let self else {
                print("onViewInit, weak self is gone")
                return
            }
            appearedDuringWaitAfterOnBody = true
            removeOnAppearBlock(onAppearId ?? "")
        }
        
        var id: String? = nil
        id = addOnBodyBlock {
            [weak self] in
            guard let self else {
                print("onViewInit, weak self is gone")
                return
            }
            guard span != nil else {
                print("onViewInit, span already ended, did this happen twice?")
                return
            }
            
            // store the back date in case we don't have an appearance
            let time = Date()
            
            // we want to tryand get the appear if we can
            // otherwise, backdate it to the body block.
            RunLoop.main.perform(inModes: [.common]) {
                self._remove(span, time: appearedDuringWaitAfterOnBody ? nil : time)
                self.removeOnBodyBlock(id ?? "")
                self.removeOnAppearBlock(onAppearId ?? "")
                span = nil
            }
        }
    }
}
