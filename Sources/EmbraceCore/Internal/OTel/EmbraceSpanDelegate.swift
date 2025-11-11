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
    func onSpanAttributesUpdated(_ span: EmbraceSpan, key: String, value: EmbraceAttributeValue?, attributes: EmbraceAttributes)
    func onSpanEnded(_ span: EmbraceSpan, endTime: Date)
}

protocol EmbraceSpanDataSource: AnyObject {
    func createEvent(
        for span: EmbraceSpan,
        name: String,
        type: EmbraceType?,
        timestamp: Date,
        attributes: EmbraceAttributes,
        internalAttributes: EmbraceAttributes,
        currentCount: Int,
        isSessionEvent: Bool
    ) throws -> EmbraceSpanEvent

    func createLink(
        for span: EmbraceSpan,
        spanId: String,
        traceId: String,
        attributes: EmbraceAttributes,
        currentCount: Int
    ) throws -> EmbraceSpanLink

    func validateAttribute(
        for span: EmbraceSpan,
        key: String,
        value: EmbraceAttributeValue?,
        currentCount: Int
    ) throws -> (String, EmbraceAttributeValue?)
}
