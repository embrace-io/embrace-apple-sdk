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
    ///    - type: The type of the span. Will be set as the `emb.type` attribute.
    ///    - startTime: The start time of the span.
    ///    - attributes: A dictionary of attributes to set on the span.
    /// - Returns: An `EmbraceSpan` or nil if the root span was not found.
    public func createChildSpan(
        name: String,
        type: EmbraceType = .startup,
        startTime: Date = Date(),
        endTime: Date? = nil,
        attributes: [String: String] = [:]
    ) -> EmbraceSpan? {
        guard let otel = otel else {
            return nil
        }

        return state.withLock {
            guard let rootSpan = $0.rootSpan else {
                return nil
            }

            return try? otel.createSpan(
                name: name,
                parentSpan: rootSpan,
                type: type,
                startTime: startTime,
                endTime: endTime,
                attributes: attributes
            )
        }
    }

    /// Method used to add attributes to the startup instrumentation root span.
    /// - Parameters:
    ///   - attributes: A dictionary of attributes to add to the trace. Each key-value pair represents an attribute.
    /// - Returns: A boolean indicating if the operation was succesful.
    @discardableResult
    public func addAttributesToTrace(_ attributes: [String: String]) throws -> Bool {

        return try state.withLock {
            guard let rootSpan = $0.rootSpan else {
                return false
            }

            try attributes.forEach {
                try rootSpan.setAttribute(key: $0.key, value: $0.value)
            }

            return true
        }
    }
}
