//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import TestSupport
@testable import EmbraceCore
@testable import EmbraceConfigInternal
import EmbraceStorageInternal
@testable import EmbraceConfiguration

class NetworkPayloadCaptureHandlerTests: XCTestCase {

    var rules: [NetworkPayloadCaptureRule] = [
        NetworkPayloadCaptureRule(
            id: "rule1",
            urlRegex: "www.test.com/user/*",
            statusCodes: [500],
            method: "GET",
            expiration: 9999999999,
            publicKey: TestConstants.rsaSanitizedPublicKey
        ),

        NetworkPayloadCaptureRule(
            id: "rule2",
            urlRegex: "www.test.com/test/*",
            statusCodes: [-1],
            method: "POST",
            expiration: 9999999999,
            publicKey: TestConstants.rsaSanitizedPublicKey
        )
    ]

    func test_updateRules() throws {
        // given a handler
        let handler = NetworkPayloadCaptureHandler(otel: nil)
        XCTAssertEqual(handler.rules.count, 0)

        // when updating the rules
        handler.updateRules(rules)

        // then the rules are updated correctly
        XCTAssertEqual(handler.rules.count, 2)
        XCTAssertEqual(handler.rules[0].id, "rule1")
        XCTAssertEqual(handler.rules[1].id, "rule2")
    }

    func test_onSessionStart() throws {
        // given a handler
        let handler = NetworkPayloadCaptureHandler(otel: nil)
        handler.rulesTriggeredMap = ["rule1": true]
        handler.active = false
        handler.currentSessionId = nil

        // when a session starts
        let session = MockSession(
            id: TestConstants.sessionId,
            processId: TestConstants.processId,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date()
        )
        let notification = Notification(name: .embraceSessionDidStart, object: session)
        handler.onSessionStart(notification)

        // then the handler is activated,
        // the trigger state for rules is reset
        // and the current session id is correct
        XCTAssert(handler.active)
        XCTAssertEqual(handler.rulesTriggeredMap.count, 0)
        XCTAssertEqual(handler.currentSessionId, TestConstants.sessionId)
    }

    func test_onSessionEnd() throws {
        // given a handler
        let handler = NetworkPayloadCaptureHandler(otel: nil)
        handler.active = true
        handler.currentSessionId = TestConstants.sessionId

        // when a session ends
        handler.onSessionEnd()

        // then the handler is deactivated
        // anb the current session id is empty
        XCTAssertFalse(handler.active)
        XCTAssertNil(handler.currentSessionId)
    }

    func test_processUnactive_validRequest() throws {
        // given a deactivated handler
        let otel = MockEmbraceOpenTelemetry()
        let handler = NetworkPayloadCaptureHandler(otel: otel)
        handler.active = false

        // when processing a request
        handler.process(
            request: URLRequest(url: URL(string: "www.test.com")!),
            response: nil,
            data: nil,
            error: nil,
            startTime: nil,
            endTime: nil
        )

        // then no logs are generated
        XCTAssertEqual(otel.logs.count, 0)
    }

    func test_processActive_invalidRequest() throws {
        // given a handler with no rules
        let otel = MockEmbraceOpenTelemetry()
        let handler = NetworkPayloadCaptureHandler(otel: otel)
        handler.active = true

        // when processing a request
        handler.process(
            request: nil,
            response: nil,
            data: nil,
            error: nil,
            startTime: nil,
            endTime: nil
        )

        // then no logs are generated
        XCTAssertEqual(otel.logs.count, 0)
    }

    func test_processActive_requestWithNoRule() throws {
        // given a handler
        let otel = MockEmbraceOpenTelemetry()
        let handler = NetworkPayloadCaptureHandler(otel: otel)
        handler.active = true
        handler.updateRules(rules)

        // when processing a request that doesn't trigger any rules
        var request = URLRequest(url: URL(string: "www.test.com")!)
        request.httpMethod = "GET"

        handler.process(
            request: request,
            response: nil,
            data: nil,
            error: nil,
            startTime: nil,
            endTime: nil
        )

        // then no logs are generated
        XCTAssertEqual(otel.logs.count, 0)
    }

    func test_processActive_requestWithRule() throws {
        // given a handler
        let otel = MockEmbraceOpenTelemetry()
        let handler = NetworkPayloadCaptureHandler(otel: otel)
        handler.active = true
        handler.updateRules(rules)

        // when processing a request that triggers a rule
        let url = URL(string: "www.test.com/user/1234")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)

        handler.process(
            request: request,
            response: response,
            data: TestConstants.data,
            error: nil,
            startTime: nil,
            endTime: nil
        )

        // then a log is generated
        XCTAssertEqual(otel.logs.count, 1)
        XCTAssertEqual(otel.logs[0].attributes["emb.type"], .string("sys.network_capture"))
        XCTAssertEqual(otel.logs[0].attributes["url"], .string("www.test.com/user/1234"))
        XCTAssertEqual(otel.logs[0].attributes["encryption-mechanism"], .string("hybrid"))
        XCTAssertNotNil(otel.logs[0].attributes["encrypted-payload"])
        XCTAssertEqual(otel.logs[0].attributes["payload-algorithm"], .string("aes-256-cbc"))
        XCTAssertEqual(otel.logs[0].attributes["key-algorithm"], .string("RSA.PKCS1"))
        XCTAssertNotNil(otel.logs[0].attributes["encrypted-key"])
    }
}
