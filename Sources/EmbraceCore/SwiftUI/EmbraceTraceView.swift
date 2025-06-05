//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import SwiftUI
import OpenTelemetryApi
#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceSemantics
#endif

@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6.0, *)
public struct EmbraceTraceView<Content: View>: View {
    
    @Environment(\.embraceTraceViewContext)
    private var context: EmbraceTraceViewContext

    @Environment(\.embraceTraceViewLogger)
    private var logger: EmbraceTraceViewLogger
    
    let content: () -> Content
    let name: String
    let attributes: [String: String]?

    public init(
        _ viewName: String,
        attributes: [String: String]? = nil,
        content: @escaping () -> Content
    ) {
        self.content = content
        self.name = viewName
        self.attributes = attributes
    }
    
    public var body: some View {
        
        // check the case where logging is off, we just return the content.
        // Check if SwiftUI view instrumentation is enabled
        guard let config = logger.config, config.isSwiftUiViewInstrumentationEnabled else {
            return content().onAppear().onDisappear()
        }
        
        let time = Date()
        
        // If this is the first span of this cycle, then we make the root.
        if context.firstCycleSpan == nil {
            context.firstCycleSpan = logger.cycledSpan(
                name,
                semantics: SpanSemantics.SwiftUIView.cycleName,
                time: time,
                parent: nil,
                attributes: attributes
            ) {
                context.firstCycleSpan = nil
            }
        }
        
        let span = logger.startSpan(
            name,
            semantics: SpanSemantics.SwiftUIView.bodyName,
            time: time,
            parent: context.firstCycleSpan,
            attributes: attributes
        )
        defer {
            logger.endSpan(span)
        }
        
        randomHang()
        
        return content()
            .onAppear {
                logger.cycledSpan(
                    name,
                    semantics: SpanSemantics.SwiftUIView.appearName,
                    parent: context.firstCycleSpan,
                    attributes: attributes
                ) {}
                randomHang()
            }
            .onDisappear {
                logger.cycledSpan(
                    name,
                    semantics: SpanSemantics.SwiftUIView.disappearName,
                    parent: context.firstCycleSpan,
                    attributes: attributes
                ) {}
                randomHang()
            }
    }
}

private func randomHang() {
#if DEBUG
    if Bool.random() {
        Thread.sleep(forTimeInterval: TimeInterval.random(in: 0...1))
    }
#endif
}

