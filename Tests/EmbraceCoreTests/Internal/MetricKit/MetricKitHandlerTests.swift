//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//
import XCTest
@testable import EmbraceCore
import TestSupport
import EmbraceCommonInternal

class MetricKitHandlerTests: XCTestCase {
    
    func dummyPayload() -> MetricKitDiagnosticPayload {
        return MetricKitDiagnosticPayload(
            startTime: Date(timeIntervalSince1970: 0),
            endTime: Date(timeIntervalSince1970: 20),
            crashes: [ MetricKitCrashData(data: TestConstants.data, signal: 9) ]
        )
    }

    func dummySession(startTime: Date, endTime: Date?, heartbeatTime: Date) -> MockSession {
        return MockSession(
            id: TestConstants.sessionId,
            processId: TestConstants.processId,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: startTime,
            endTime: endTime,
            lastHeartbeatTime: heartbeatTime
        )
    }

    func test_forwardsPayload() {
        // given a handler with a listener
        let handler = MetricKitHandler()
        let listener = MockMetricKitCrashPayloadListener()
        handler.add(listener: listener)

        // when it receives a payload
        let payload = dummyPayload()
        handler.handlePayload(payload)

        // then it gets forwarded to the listener
        XCTAssertTrue(listener.didReceivePayload)
        XCTAssertEqual(listener.payloadData, payload.crashes[0].data)
        XCTAssertEqual(listener.payloadSignal, payload.crashes[0].signal)
        XCTAssertNil(listener.sessionId)
    }

    func test_linked_session_endTime() {
        // given a handler with session data that can be linked
        let handler = MetricKitHandler()
        let listener = MockMetricKitCrashPayloadListener()
        handler.add(listener: listener)

        handler.lastSession = dummySession(
            startTime: Date(timeIntervalSince1970: 10),
            endTime: Date(timeIntervalSince1970: 18), 
            heartbeatTime: Date(timeIntervalSince1970: 11)
        )

        // when it receives a payload
        let payload = dummyPayload()
        handler.handlePayload(payload)

        // then it gets forwarded to the listener with a session id
        XCTAssertTrue(listener.didReceivePayload)
        XCTAssertEqual(listener.sessionId, handler.lastSession?.id)
    }

    func test_linked_session_lastHeartbeatTime() {
        // given a handler with session data that can be linked
        let handler = MetricKitHandler()
        let listener = MockMetricKitCrashPayloadListener()
        handler.add(listener: listener)

        handler.lastSession = dummySession(
            startTime: Date(timeIntervalSince1970: 10),
            endTime: nil,
            heartbeatTime: Date(timeIntervalSince1970: 18)
        )

        // when it receives a payload
        let payload = dummyPayload()
        handler.handlePayload(payload)

        // then it gets forwarded to the listener with a session id
        XCTAssertTrue(listener.didReceivePayload)
        XCTAssertEqual(listener.sessionId, handler.lastSession?.id)
    }

    func test_no_linked_session() {
        // given a handler with session data that can not be linked
        let handler = MetricKitHandler()
        let listener = MockMetricKitCrashPayloadListener()
        handler.add(listener: listener)

        handler.lastSession = dummySession(
            startTime: Date(timeIntervalSince1970: 100),
            endTime: Date(timeIntervalSince1970: 200),
            heartbeatTime: Date(timeIntervalSince1970: 180)
        )

        // when it receives a payload
        let payload = dummyPayload()
        handler.handlePayload(payload)

        // then it gets forwarded to the listener without a session id
        XCTAssertTrue(listener.didReceivePayload)
        XCTAssertNil(listener.sessionId)
    }
}
