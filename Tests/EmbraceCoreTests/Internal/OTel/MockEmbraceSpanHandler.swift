//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceSemantics
import XCTest

@testable import EmbraceCore

class MockEmbraceSpanHandler: EmbraceSpanHandler {

    var createEventCallCount: Int = 0
    var createEventError: Error?
    var createEventCurrentCount: Int?
    func createEvent(
        forSpanNamed spanName: String,
        name: String,
        type: EmbraceType?,
        timestamp: Date,
        attributes: EmbraceAttributes,
        internalAttributes: EmbraceAttributes,
        currentCount: Int,
        isSessionEvent: Bool
    ) throws -> EmbraceSpanEvent {
        createEventCallCount += 1
        createEventCurrentCount = currentCount

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
    var createLinkCurrentCount: Int?
    func createLink(
        forSpanNamed spanName: String,
        spanId: String,
        traceId: String,
        attributes: EmbraceAttributes,
        currentCount: Int
    ) throws -> EmbraceSpanLink {
        createLinkCallCount += 1
        createLinkCurrentCount = currentCount

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
        value: EmbraceAttributeValue?,
        currentCount: Int
    ) throws -> (String, EmbraceAttributeValue?) {
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
    func onSpanAttributesUpdated(_ span: EmbraceSpan, key: String, value: EmbraceAttributeValue?, attributes: EmbraceAttributes) {
        onSpanAttributesUpdatedCallCount += 1
    }

    /// The end times the handler was notified with, in the order they arrived.
    ///
    /// Held behind a lock because several threads can end the same span at once. A plain
    /// `count += 1` is a read-modify-write, so concurrent ends could lose an increment and make a
    /// double notification look like a single one.
    private let _onSpanEndedTimes = EmbraceMutex<[Date]>([])

    var onSpanEndedTimes: [Date] {
        _onSpanEndedTimes.safeValue
    }

    var onSpanEndedCallCount: Int {
        _onSpanEndedTimes.safeValue.count
    }

    func onSpanEnded(_ span: EmbraceSpan, endTime: Date) {
        _onSpanEndedTimes.withLock { $0.append(endTime) }
    }
}
