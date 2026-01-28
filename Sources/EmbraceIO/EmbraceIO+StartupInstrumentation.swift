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
    ///    - type: The type of the span. Will be set as the `emb.type` attribute.
    ///    - startTime: The start time of the span.
    ///    - attributes: A dictionary of attributes to set on the span.
    /// - Returns: An OpenTelemetry `SpanBuilder` or nil if the root span was not found.
    public func buildStartupChildSpan(
        name: String,
        type: SpanType = .startup,
        startTime: Date = Date(),
        attributes: [String: String] = [:]
    ) -> SpanBuilder? {
        return Embrace.client?.startupInstrumentation.buildChildSpan(
            name: name,
            type: type,
            startTime: startTime,
            attributes: attributes
        )
    }

    /// Method used to record a completed span to be included as a child span to the startup instrumenstation root span.
    /// - Parameters:
    ///    - name: The name of the span.
    ///    - type: The type of the span. Will be set as the `emb.type` attribute.
    ///    - startTime: The start time of the span.
    ///    - endTime: The end time of the span.
    ///    - attributes: A dictionary of attributes to set on the span.
    /// - Returns: A boolean indicating if the operation was succesful.
    @discardableResult
    public func recordCompletedStartupChildSpan(
        name: String,
        type: SpanType = .viewLoad,
        startTime: Date,
        endTime: Date,
        attributes: [String: String] = [:]
    ) -> Bool {
        return Embrace.client?.startupInstrumentation.recordCompletedChildSpan(
            name: name,
            type: type,
            startTime: startTime,
            endTime: endTime,
            attributes: attributes
        ) ?? false
    }

    /// Method used to add attributes to the startup instrumentation root span.
    /// - Parameters:
    ///   - attributes: A dictionary of attributes to add to the trace. Each key-value pair represents an attribute.
    /// - Returns: A boolean indicating if the operation was succesful.
    @discardableResult
    public func addAttributesToStartupTrace(_ attributes: [String: String]) -> Bool {
        return Embrace.client?.startupInstrumentation.addAttributesToTrace(attributes) ?? false
    }
}
