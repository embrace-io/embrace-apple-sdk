//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceSemantics
import TestSupport
import XCTest

@testable import EmbraceCore

class MockOTelSignalBridge: EmbraceOTelSignalBridge {

    var startSpanCallCount: Int = 0
    var startSpanReturnValue: EmbraceSpanContext?
    func startSpan(
        name: String,
        parentSpan: EmbraceSpan?,
        status: EmbraceSpanStatus,
        startTime: Date,
        endTime: Date?,
        events: [EmbraceSpanEvent],
        links: [EmbraceSpanLink],
        attributes: EmbraceAttributes
    ) -> EmbraceSpanContext {
        startSpanCallCount += 1

        return startSpanReturnValue
            ?? EmbraceSpanContext(
                spanId: String.randomSpanId(),
                traceId: parentSpan?.context.traceId ?? String.randomTraceId()
            )
    }

    var updateSpanStatusCallCount: Int = 0
    func updateSpanStatus(_ span: any EmbraceSpan, status: EmbraceSpanStatus) {
        updateSpanStatusCallCount += 1
    }

    var updateSpanAttributeCallCount: Int = 0
    func updateSpanAttribute(_ span: any EmbraceSpan, key: String, value: EmbraceAttributeValue?) {
        updateSpanAttributeCallCount += 1
    }

    var addSpanEventCallCount: Int = 0
    func addSpanEvent(_ span: any EmbraceSpan, event: EmbraceSpanEvent) {
        addSpanEventCallCount += 1
    }

    var addSpanLinkCallCount: Int = 0
    func addSpanLink(_ span: any EmbraceSpan, link: EmbraceSpanLink) {
        addSpanLinkCallCount += 1
    }

    var endSpanCallCount: Int = 0
    func endSpan(_ span: any EmbraceSpan, endTime: Date) {
        endSpanCallCount += 1
    }

    var createLogCallCount: Int = 0
    func createLog(_ log: any EmbraceLog) {
        createLogCallCount += 1
    }
}
