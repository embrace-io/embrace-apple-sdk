//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)

    import Foundation
    import UIKit
    #if !EMBRACE_COCOAPOD_BUILDING_SDK
        import EmbraceCommonInternal
        import EmbraceSemantics
    #endif
    import OpenTelemetryApi

    public protocol InstrumentableViewController: UIViewController {

    }

    extension InstrumentableViewController {

        /// Method used to build a span to be included as a child span to the parent span being handled by the `ViewCaptureService`.
        /// - Parameters:
        ///    - name: The name of the span.
        ///    - type: The type of the span. Will be set as the `emb.type` attribute.
        ///    - startTime: The start time of the span.
        ///    - attributes: A dictionary of attributes to set on the span.
        /// - Returns: An OpenTelemetry `SpanBuilder`.
        /// - Throws: `ViewCaptureService.noServiceFound` if no `ViewCaptureService` is active.
        /// - Throws: `ViewCaptureService.firstRenderInstrumentationDisabled` if this functionallity was not enabled when setting up the `ViewCaptureService`, or the remote configuration for this feature was not enabled.
        /// - Throws: `ViewCaptureService.parentSpanNotFound` if no parent span was found for this `UIViewController`.
        ///           This could mean the `UIViewController` was already rendered / deemed interactive, or the `UIViewController` has already disappeared.
        public func buildChildSpan(
            name: String,
            type: SpanType = .viewLoad,
            startTime: Date = Date(),
            attributes: [String: String] = [:]
        ) throws -> SpanBuilder? {
            return try Embrace.client?.captureServices.buildChildSpan(
                for: self,
                name: name,
                type: type,
                startTime: startTime,
                attributes: attributes
            )
        }

        /// Method used to record a completed span to be included as a child span to the parent span being handled by the `ViewCaptureService`.
        /// - Parameters:
        ///    - name: The name of the span.
        ///    - type: The type of the span. Will be set as the `emb.type` attribute.
        ///    - startTime: The start time of the span.
        ///    - endTime: The end time of the span.
        ///    - attributes: A dictionary of attributes to set on the span.
        /// - Throws: `ViewCaptureService.noServiceFound` if no `ViewCaptureService` is active.
        /// - Throws: `ViewCaptureService.firstRenderInstrumentationDisabled` if this functionallity was not enabled when setting up the `ViewCaptureService`, or the remote configuration for this feature was not enabled.
        /// - Throws: `ViewCaptureService.parentSpanNotFound` if no parent span was found for this `UIViewController`.
        ///           This could mean the `UIViewController` was already rendered / deemed interactive, or the `UIViewController` has already disappeared.
        public func recordCompletedChildSpan(
            name: String,
            type: SpanType = .viewLoad,
            startTime: Date,
            endTime: Date,
            attributes: [String: String] = [:]
        ) throws {
            try Embrace.client?.captureServices.recordCompletedChildSpan(
                for: self,
                name: name,
                type: type,
                startTime: startTime,
                endTime: endTime,
                attributes: attributes
            )
        }

        /// Method used to add attributes to the active trace associated with the render process of a `UIViewController`.
        /// These attributes will be appended to the ongoing trace handled by the `ViewCaptureService`.
        ///
        /// - Parameters:
        ///   - attributes: A dictionary of attributes to add to the trace. Each key-value pair represents an attribute.
        /// - Throws: `ViewCaptureService.serviceNotFound` if no `ViewCaptureService` is active.
        /// - Throws: `ViewCaptureService.firstRenderInstrumentationDisabled` if this functionallity was not enabled when setting up the `ViewCaptureService`, or the remote configuration for this feature was not enabled.
        /// - Throws: `ViewCaptureService.parentSpanNotFound` if no parent span was found for this `UIViewController`.
        ///            This could mean the `UIViewController` was already rendered / deemed interactive, or the `UIViewController` has already disappeared.
        /// - Note: Attributes added using this method are specific to the ongoing trace associated with this `UIViewController`.
        public func addAttributesToTrace(_ attributes: [String: String]) throws {
            try Embrace.client?.captureServices.addAttributesToTrace(
                for: self,
                attributes: attributes
            )
        }
    }

#endif
