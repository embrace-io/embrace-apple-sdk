//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceSemantics
#endif

extension EmbraceIO {

    /// Method used to build a span to be included as a child span to the startup instrumentation root span.
    /// - Parameters:
    ///    - name: The name of the span.
    ///    - startTime: The start time of the span.
    ///    - attributes: A dictionary of attributes to set on the span.
    /// - Returns: An `EmbraceSpan` or nil if the root span was not found.
    public func createStartupChildSpan(
        name: String,
        startTime: Date = Date(),
        endTime: Date? = nil,
        attributes: EmbraceAttributes = [:]
    ) -> EmbraceSpan? {
        return Embrace.client?.startupInstrumentation.createStartupChildSpan(
            name: name,
            startTime: startTime,
            endTime: endTime,
            attributes: attributes
        )
    }

    /// Method used to add attributes to the startup instrumentation root span.
    /// If the root span is not found or an attribute fails to be set, a warning is logged.
    /// - Parameters:
    ///   - attributes: A dictionary of attributes to add to the trace. Each key-value pair represents an attribute.
    /// - Returns: A boolean indicating if the operation was succesful.
    @discardableResult
    public func addAttributesToStartupTrace(_ attributes: EmbraceAttributes) -> Bool {
        Embrace.client?.startupInstrumentation.addAttributesToStartupTrace(attributes) ?? false
    }
}
