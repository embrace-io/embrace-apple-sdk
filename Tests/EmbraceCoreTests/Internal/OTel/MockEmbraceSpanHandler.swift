//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceSemantics
import XCTest

@testable import EmbraceCore

class MockEmbraceSpanHandler: EmbraceSpanHandler {

    var createEventCallCount: Int = 0
    var createEventError: Error?
    func createEvent(
        for span: EmbraceSpan,
        name: String,
        type: EmbraceType?,
        timestamp: Date,
        attributes: [String: String],
        internalAttributes: [String: String],
        currentCount: Int,
        isSessionEvent: Bool
    ) throws -> EmbraceSpanEvent {
        createEventCallCount += 1

        if let createEventError {
            throw createEventError
        }

        return EmbraceSpanEvent(
            name: name,
            type: type,
            timestamp: timestamp,
            attributes: internalAttributes.merging(attributes) { (current, _) in current }
        )
    }

    var createLinkCallCount: Int = 0
    var createLinkError: Error?
    func createLink(
        for span: EmbraceSpan,
        spanId: String,
        traceId: String,
        attributes: [String: String],
        currentCount: Int
    ) throws -> EmbraceSpanLink {
        createLinkCallCount += 1

        if let createLinkError {
            throw createLinkError
        }

        return EmbraceSpanLink(
            spanId: spanId,
            traceId: traceId,
            attributes: attributes
        )
    }

    var validateAttributeCallCount: Int = 0
    var validateAttributeError: Error? = nil
    func validateAttribute(
        for span: EmbraceSpan,
        key: String,
        value: String?,
        currentCount: Int
    ) throws -> (String, String?) {
        validateAttributeCallCount += 1

        if let validateAttributeError {
            throw validateAttributeError
        }

        return (key, value)
    }

    var onSpanStatusUpdatedCallCount: Int = 0
    func onSpanStatusUpdated(_ span: EmbraceSpan, status: EmbraceSpanStatus) {
        onSpanStatusUpdatedCallCount += 1
    }

    var onSpanEventAddedCallCount: Int = 0
    func onSpanEventAdded(_ span: EmbraceSpan, event: EmbraceSpanEvent) {
        onSpanEventAddedCallCount += 1
    }

    var onSpanLinkAddedCallCount: Int = 0
    func onSpanLinkAdded(_ span: EmbraceSpan, link: EmbraceSpanLink) {
        onSpanLinkAddedCallCount += 1
    }

    var onSpanAttributesUpdatedCallCount: Int = 0
    func onSpanAttributesUpdated(_ span: EmbraceSpan, attributes: [String: String]) {
        onSpanAttributesUpdatedCallCount += 1
    }

    var onSpanEndedCallCount: Int = 0
    func onSpanEnded(_ span: EmbraceSpan, endTime: Date) {
        onSpanEndedCallCount += 1
    }
}
