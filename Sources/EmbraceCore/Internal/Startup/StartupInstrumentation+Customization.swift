//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceSemantics
#endif

extension StartupInstrumentation {

    /// Method used to build a span to be included as a child span to the startup instrumentation root span.
    /// - Parameters:
    ///    - name: The name of the span.
    ///    - startTime: The start time of the span.
    ///    - attributes: A dictionary of attributes to set on the span.
    /// - Returns: An `EmbraceSpan` or nil if the root span was not found.
    package func createStartupChildSpan(
        name: String,
        startTime: Date = Date(),
        endTime: Date? = nil,
        attributes: EmbraceAttributes = [:]
    ) -> EmbraceSpan? {
        guard let otel = otel else {
            return nil
        }

        return state.withLock {
            guard let rootSpan = $0.rootSpan else {
                return nil
            }

            return try? otel.createInternalSpan(
                name: name,
                parentSpan: rootSpan,
                type: .startup,
                startTime: startTime,
                endTime: endTime,
                attributes: attributes
            )
        }
    }

    /// Method used to add attributes to the startup instrumentation root span.
    /// - Parameters:
    ///   - attributes: A dictionary of attributes to add to the trace. Each key-value pair represents an attribute.
    package func addAttributesToStartupTrace(_ attributes: EmbraceAttributes) {

        return state.withLock {
            guard let rootSpan = $0.rootSpan else {
                return
            }

            for (key, value) in attributes {
                rootSpan.setAttribute(key: key, value: value)
            }
        }
    }
}
