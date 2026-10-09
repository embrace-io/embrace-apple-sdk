//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

typealias EmbraceSpanHandler = EmbraceSpanDelegate & EmbraceSpanDataSource

protocol EmbraceSpanDelegate: AnyObject {
    func onSpanStatusUpdated(_ span: EmbraceSpan, status: EmbraceSpanStatus)
    func onSpanEventAdded(_ span: EmbraceSpan, event: EmbraceSpanEvent)
    func onSpanLinkAdded(_ span: EmbraceSpan, link: EmbraceSpanLink)
    func onSpanAttributeUpdated(_ span: EmbraceSpan, key: String, value: EmbraceAttributeValue?)
    func onSpanEnded(_ span: EmbraceSpan, endTime: Date)
}

protocol EmbraceSpanDataSource: AnyObject {
    func createEvent(
        forSpanNamed spanName: String,
        name: String,
        type: EmbraceType?,
        timestamp: Date,
        attributes: EmbraceAttributes,
        internalAttributes: EmbraceAttributes,
        currentCount: Int,
        isSessionEvent: Bool
    ) throws -> EmbraceSpanEvent

    func createLink(
        forSpanNamed spanName: String,
        spanId: String,
        traceId: String,
        attributes: EmbraceAttributes,
        currentCount: Int
    ) throws -> EmbraceSpanLink

    /// Validates an attribute before it is written to a span.
    ///
    /// The span's current attributes are passed in rather than read back from the span so that the
    /// caller can hold its own lock across the validation and the write, keeping the limit check and
    /// the write that consumes a slot in a single critical section.
    func validateAttribute(
        forSpanNamed spanName: String,
        key: String,
        value: EmbraceAttributeValue?,
        currentAttributes: EmbraceAttributes,
        currentCount: Int
    ) throws -> (String, EmbraceAttributeValue?)
}
