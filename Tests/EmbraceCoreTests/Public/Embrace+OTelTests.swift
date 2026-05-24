//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceOTelInternal
import OpenTelemetrySdk
import TestSupport
import XCTest

@testable import EmbraceCore

final class Embrace_OTelTests: XCTestCase {

    var client: Embrace!

    override func setUpWithError() throws {
        client = try Embrace(
            options: .init(appId: "debug", captureServices: [], crashReporter: nil),
            embraceStorage: .createInMemoryDb()
        )
    }

    override func tearDownWithError() throws {
        client = nil
    }

    func test_tracer_retrievesTracerInstance() throws {
        let tracer = client.tracer(instrumentationName: "ExampleTracer")
        XCTAssertNotNil(tracer)
    }

    // MARK: - autoParentOrphanSpansToSession

    private func makeClientWithSession(
        autoParentOrphanSpansToSession: Bool = false,
        spanProcessor: MockSpanProcessor
    ) throws -> Embrace {
        let c = try Embrace(
            options: .init(
                appId: "debug",
                captureServices: [],
                crashReporter: nil,
                autoParentOrphanSpansToSession: autoParentOrphanSpansToSession
            ),
            embraceStorage: .createInMemoryDb()
        )
        // Override sdkStateProvider so isEnabled returns true without calling start()
        c.sessionController.sdkStateProvider = MockEmbraceSDKStateProvider()
        EmbraceOTel.setup(spanProcessors: [spanProcessor])
        c.sessionController.startSession(state: .foreground)
        return c
    }

    func test_buildSpan_withAutoParentDisabled_hasNoParent() throws {
        let spanProcessor = MockSpanProcessor()
        let c = try makeClientWithSession(spanProcessor: spanProcessor)

        _ = c.buildSpan(name: "test-span").startSpan()

        // first started span is the session span; last is our test span
        let testSpanData = spanProcessor.startedSpans.last
        XCTAssertNil(testSpanData?.parentSpanId)
    }

    func test_buildSpan_withAutoParentEnabled_usesSessionSpanAsParent() throws {
        let spanProcessor = MockSpanProcessor()
        let c = try makeClientWithSession(autoParentOrphanSpansToSession: true, spanProcessor: spanProcessor)

        let sessionSpanId = c.sessionController.currentSessionSpan?.context.spanId
        XCTAssertNotNil(sessionSpanId)

        _ = c.buildSpan(name: "test-span").startSpan()

        let testSpanData = spanProcessor.startedSpans.last
        XCTAssertEqual(testSpanData?.parentSpanId, sessionSpanId)
    }

    func test_recordCompletedSpan_withAutoParentEnabled_usesSessionSpanAsParent() throws {
        let spanProcessor = MockSpanProcessor()
        let c = try makeClientWithSession(autoParentOrphanSpansToSession: true, spanProcessor: spanProcessor)

        let sessionSpanId = c.sessionController.currentSessionSpan?.context.spanId
        XCTAssertNotNil(sessionSpanId)

        let now = Date()
        c.recordCompletedSpan(
            name: "test-span",
            type: .performance,
            parent: nil,
            startTime: now,
            endTime: now.addingTimeInterval(1),
            attributes: [:],
            events: [],
            errorCode: nil
        )

        let testSpanData = spanProcessor.endedSpans.last
        XCTAssertEqual(testSpanData?.parentSpanId, sessionSpanId)
    }

    func test_recordCompletedSpan_withExplicitParent_doesNotUseSessionSpan() throws {
        let spanProcessor = MockSpanProcessor()
        let c = try makeClientWithSession(autoParentOrphanSpansToSession: true, spanProcessor: spanProcessor)

        let explicitParent = c.buildSpan(name: "explicit-parent").startSpan()
        let explicitParentSpanId = (explicitParent as? ReadableSpan)?.toSpanData().spanId

        let now = Date()
        c.recordCompletedSpan(
            name: "test-span",
            type: .performance,
            parent: explicitParent,
            startTime: now,
            endTime: now.addingTimeInterval(1),
            attributes: [:],
            events: [],
            errorCode: nil
        )

        let testSpanData = spanProcessor.endedSpans.last
        XCTAssertEqual(testSpanData?.parentSpanId, explicitParentSpanId)
    }
}
