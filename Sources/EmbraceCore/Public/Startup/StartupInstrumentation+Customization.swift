//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi
#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceCommonInternal
import EmbraceSemantics
#endif

public extension StartupInstrumentation {

    /// Method used to build a span to be included as a child span to the startup instrumentation root span.
    /// - Parameters:
    ///    - name: The name of the span.
    ///    - type: The type of the span. Will be set as the `emb.type` attribute.
    ///    - startTime: The start time of the span.
    ///    - attributes: A dictionary of attributes to set on the span.
    /// - Returns: An OpenTelemetry `SpanBuilder` or nil if the root span was not found.
    func buildChildSpan(
        name: String,
        type: SpanType = .startup,
        startTime: Date = Date(),
        attributes: [String: String] = [:]
    ) -> SpanBuilder? {
        guard let otel = otel else {
            return nil
        }

        return state.withLock {
            guard let rootSpan = $0.rootSpan else {
                return nil
            }

            let builder = otel.buildSpan(
                name: name,
                type: type,
                attributes: attributes,
                autoTerminationCode: nil
            )
            builder.setStartTime(time: startTime)
            builder.setParent(rootSpan)

            return builder
        }
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
    func recordCompletedChildSpan(
        name: String,
        type: SpanType = .viewLoad,
        startTime: Date,
        endTime: Date,
        attributes: [String: String] = [:]
    ) -> Bool {
        guard let otel = otel else {
            return false
        }

        return state.withLock {
            guard let rootSpan = $0.rootSpan else {
                return false
            }

            let builder = otel.buildSpan(
                name: name,
                type: type,
                attributes: attributes,
                autoTerminationCode: nil
            )
            builder.setStartTime(time: startTime)
            builder.setParent(rootSpan)

            let span = builder.startSpan()
            span.end(time: endTime)

            return true
        }
    }

    /// Method used to add attributes to the startup instrumentation root span.
    /// - Parameters:
    ///   - attributes: A dictionary of attributes to add to the trace. Each key-value pair represents an attribute.
    /// - Returns: A boolean indicating if the operation was succesful.
    @discardableResult
    func addAttributesToTrace(_ attributes: [String: String]) -> Bool {

        return state.withLock {
            guard let rootSpan = $0.rootSpan else {
                return false
            }

            attributes.forEach {
                rootSpan.setAttribute(key: $0.key, value: .string($0.value))
            }

            // TODO: Clean up reference to client! There's currently no other way to trigger a flush!
            Embrace.client?.flush(rootSpan)

            return true
        }
    }
}
