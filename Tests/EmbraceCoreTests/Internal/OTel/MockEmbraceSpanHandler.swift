//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceSemantics
import XCTest

@testable import EmbraceCore

/// All the recorded state is kept behind a mutex so the mock can be used by tests
/// that call into a span from several threads at once.
class MockEmbraceSpanHandler: EmbraceSpanHandler {

    private struct State {
        var createEventCallCount: Int = 0
        var createEventError: Error?
        var createEventCurrentCount: Int?
        var createEventLimit: Int?

        var createLinkCallCount: Int = 0
        var createLinkError: Error?
        var createLinkCurrentCount: Int?
        var createLinkLimit: Int?

        var validateAttributeCallCount: Int = 0
        var validateAttributeError: Error?
        var validateAttributeCurrentCount: Int?
        var validateAttributeLimit: Int?

        var onSpanStatusUpdatedCallCount: Int = 0
        var onSpanEventAddedCallCount: Int = 0
        var onSpanLinkAddedCallCount: Int = 0
        var onSpanAttributeUpdatedCallCount: Int = 0
        var onSpanEndedCallCount: Int = 0
    }
    private let state = EmbraceMutex(State())

    var createEventCallCount: Int {
        get { state.safeValue.createEventCallCount }
        set { state.withLock { $0.createEventCallCount = newValue } }
    }

    var createEventError: Error? {
        get { state.safeValue.createEventError }
        set { state.withLock { $0.createEventError = newValue } }
    }

    var createEventCurrentCount: Int? {
        get { state.safeValue.createEventCurrentCount }
        set { state.withLock { $0.createEventCurrentCount = newValue } }
    }

    /// When set, `createEvent` rejects any call whose `currentCount` already reached this value,
    /// the same way the real handler enforces the span event limit.
    var createEventLimit: Int? {
        get { state.safeValue.createEventLimit }
        set { state.withLock { $0.createEventLimit = newValue } }
    }

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
        let error = state.withLock { state -> Error? in
            state.createEventCallCount += 1
            state.createEventCurrentCount = currentCount

            if let limit = state.createEventLimit, currentCount >= limit {
                return EmbraceOTelError.spanEventLimitReached("Events limit reached for span \(spanName)")
            }

            return state.createEventError
        }

        if let error {
            throw error
        }

        return EmbraceSpanEvent(
            name: name,
            type: type,
            timestamp: timestamp,
            attributes: internalAttributes.merging(attributes) { (current, _) in current }
        )
    }

    var createLinkCallCount: Int {
        get { state.safeValue.createLinkCallCount }
        set { state.withLock { $0.createLinkCallCount = newValue } }
    }

    var createLinkError: Error? {
        get { state.safeValue.createLinkError }
        set { state.withLock { $0.createLinkError = newValue } }
    }

    var createLinkCurrentCount: Int? {
        get { state.safeValue.createLinkCurrentCount }
        set { state.withLock { $0.createLinkCurrentCount = newValue } }
    }

    /// When set, `createLink` rejects any call whose `currentCount` already reached this value,
    /// the same way the real handler enforces the span link limit.
    var createLinkLimit: Int? {
        get { state.safeValue.createLinkLimit }
        set { state.withLock { $0.createLinkLimit = newValue } }
    }

    func createLink(
        forSpanNamed spanName: String,
        spanId: String,
        traceId: String,
        attributes: EmbraceAttributes,
        currentCount: Int
    ) throws -> EmbraceSpanLink {
        let error = state.withLock { state -> Error? in
            state.createLinkCallCount += 1
            state.createLinkCurrentCount = currentCount

            if let limit = state.createLinkLimit, currentCount >= limit {
                return EmbraceOTelError.spanLinkLimitReached("Links limit reached for span \(spanName)")
            }

            return state.createLinkError
        }

        if let error {
            throw error
        }

        return EmbraceSpanLink(
            spanId: spanId,
            traceId: traceId,
            attributes: attributes
        )
    }

    var validateAttributeCallCount: Int {
        get { state.safeValue.validateAttributeCallCount }
        set { state.withLock { $0.validateAttributeCallCount = newValue } }
    }

    var validateAttributeError: Error? {
        get { state.safeValue.validateAttributeError }
        set { state.withLock { $0.validateAttributeError = newValue } }
    }

    var validateAttributeCurrentCount: Int? {
        get { state.safeValue.validateAttributeCurrentCount }
        set { state.withLock { $0.validateAttributeCurrentCount = newValue } }
    }

    /// When set, `validateAttribute` rejects any call for a new key whose `currentCount` already
    /// reached this value, the same way the real handler enforces the span attribute limit.
    var validateAttributeLimit: Int? {
        get { state.safeValue.validateAttributeLimit }
        set { state.withLock { $0.validateAttributeLimit = newValue } }
    }

    func validateAttribute(
        forSpanNamed spanName: String,
        key: String,
        value: EmbraceAttributeValue?,
        currentAttributes: EmbraceAttributes,
        currentCount: Int
    ) throws -> (String, EmbraceAttributeValue?) {
        let error = state.withLock { state -> Error? in
            state.validateAttributeCallCount += 1
            state.validateAttributeCurrentCount = currentCount

            if let limit = state.validateAttributeLimit,
                value != nil,
                currentAttributes[key] == nil,
                currentCount >= limit
            {
                return EmbraceOTelError.spanAttributeLimitReached("Attributes limit reached for span \(spanName)")
            }

            return state.validateAttributeError
        }

        if let error {
            throw error
        }

        return (key, value)
    }

    var onSpanStatusUpdatedCallCount: Int {
        state.safeValue.onSpanStatusUpdatedCallCount
    }

    func onSpanStatusUpdated(_ span: EmbraceSpan, status: EmbraceSpanStatus) {
        state.withLock { $0.onSpanStatusUpdatedCallCount += 1 }
    }

    var onSpanEventAddedCallCount: Int {
        state.safeValue.onSpanEventAddedCallCount
    }

    func onSpanEventAdded(_ span: EmbraceSpan, event: EmbraceSpanEvent) {
        state.withLock { $0.onSpanEventAddedCallCount += 1 }
    }

    var onSpanLinkAddedCallCount: Int {
        state.safeValue.onSpanLinkAddedCallCount
    }

    func onSpanLinkAdded(_ span: EmbraceSpan, link: EmbraceSpanLink) {
        state.withLock { $0.onSpanLinkAddedCallCount += 1 }
    }

    var onSpanAttributeUpdatedCallCount: Int {
        state.safeValue.onSpanAttributeUpdatedCallCount
    }

    func onSpanAttributeUpdated(_ span: EmbraceSpan, key: String, value: EmbraceAttributeValue?) {
        state.withLock { $0.onSpanAttributeUpdatedCallCount += 1 }
    }

    var onSpanEndedCallCount: Int {
        state.safeValue.onSpanEndedCallCount
    }

    func onSpanEnded(_ span: EmbraceSpan, endTime: Date) {
        state.withLock { $0.onSpanEndedCallCount += 1 }
    }
}
