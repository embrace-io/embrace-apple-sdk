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

    public protocol InstrumentableViewController: UIViewController {

    }

    extension InstrumentableViewController {

        /// Method used to build a span to be included as a child span to the parent span being handled by the `ViewCaptureService`.
        /// - Parameters:
        ///    - name: The name of the span.
        ///    - type: The type of the span. Will be set as the `emb.type` attribute.
        ///    - startTime: The start time of the span.
        ///    - endTime: The end time of the span, if any.
        ///    - attributes: A dictionary of attributes to set on the span.
        /// - Returns: An new `EmbraceSpan`.
        public func createChildSpan(
            name: String,
            type: EmbraceType = .viewLoad,
            startTime: Date = Date(),
            endTime: Date? = nil,
            attributes: EmbraceAttributes = [:]
        ) -> EmbraceSpan? {
            return try? Embrace.client?.captureServices.createChildSpan(
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
        /// - Note: Attributes added using this method are specific to the ongoing trace associated with this `UIViewController`.
        public func addAttributesToTrace(_ attributes: [String: String]) {
            try? Embrace.client?.captureServices.addAttributesToTrace(
                for: self,
                attributes: attributes
            )
        }
    }

#endif
