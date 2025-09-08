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
    func onSpanAttributesUpdated(_ span: EmbraceSpan, attributes: [String: String])
    func onSpanEnded(_ span: EmbraceSpan, endTime: Date)
}

protocol EmbraceSpanDataSource: AnyObject {
    func createEvent(
        for span: EmbraceSpan,
        name: String,
        type: EmbraceType?,
        timestamp: Date,
        attributes: [String: String],
        internalAttributes: [String: String],
        currentCount: Int
    ) throws -> EmbraceSpanEvent

    func createLink(
        for span: EmbraceSpan,
        spanId: String,
        traceId: String,
        attributes: [String: String],
        currentCount: Int
    ) throws -> EmbraceSpanLink

    func validateAttribute(
        for span: EmbraceSpan,
        key: String,
        value: String?,
        currentCount: Int
    ) throws -> (String, String?)
}
