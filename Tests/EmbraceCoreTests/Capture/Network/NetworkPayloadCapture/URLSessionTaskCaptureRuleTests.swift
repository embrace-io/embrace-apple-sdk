//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import TestSupport
@testable import EmbraceCore
@testable import EmbraceConfigInternal
@testable import EmbraceConfiguration
import EmbraceStorageInternal

class URLSessionTaskCaptureRuleTests: XCTestCase {

    let rule1 = NetworkPayloadCaptureRule(
        id: "rule1",
        urlRegex: "www.test.com/user/*",
        statusCodes: [500],
        methods: ["GET"],
        expiration: 9999999999,
        publicKey: TestConstants.rsaSanitizedPublicKey
    )

    let rule2 = NetworkPayloadCaptureRule(
        id: "rule2",
        urlRegex: "www.test.com/test",
        statusCodes: [-1],
        methods: ["POST"],
        expiration: 9999999999,
        publicKey: TestConstants.rsaPublicKey
    )

    let rule3 = NetworkPayloadCaptureRule(
        id: "rule3",
        urlRegex: "www.test.com/test",
        statusCodes: [-1],
        methods: ["POST"],
        expiration: 1,
        publicKey: TestConstants.rsaSanitizedPublicKey
    )

    func test_internalRule() {
        // given a rule based on a NetworkPayloadCaptureRule
        let rule = URLSessionTaskCaptureRule(rule: rule1)

        // then it returns the underlying values from the internal rule
        XCTAssertEqual(rule.id, rule1.id)
        XCTAssertEqual(rule.urlRegex, rule1.urlRegex)
        XCTAssertEqual(rule.expirationDate, rule1.expirationDate)
        XCTAssertEqual(rule.publicKey, rule1.publicKey)
    }

    func test_sanitizedPublicKey() {
        // given a rule based on a NetworkPayloadCaptureRule
        let rule = URLSessionTaskCaptureRule(rule: rule2)

        // then it returns the underlying values from the internal rule
        // with a sanitized public key
        XCTAssertEqual(rule.id, rule2.id)
        XCTAssertEqual(rule.urlRegex, rule2.urlRegex)
        XCTAssertEqual(rule.expirationDate, rule2.expirationDate)
        XCTAssertEqual(rule.publicKey, TestConstants.rsaSanitizedPublicKey)
    }

    func test_trigger_invalidRequest() {
        // given a rule
        let rule = URLSessionTaskCaptureRule(rule: rule1)

        // it should not trigger for an invalid request
        XCTAssertFalse(rule.shouldTriggerFor(request: nil, response: nil, error: nil))
    }

    func test_trigger_noMatch1() {
        // given a rule
        let rule = URLSessionTaskCaptureRule(rule: rule1)

        // it should not trigger for a request that doesn't match
        var request = URLRequest(url: URL(string: "www.test.com")!)
        request.httpMethod = "GET"

        XCTAssertFalse(rule.shouldTriggerFor(request: request, response: nil, error: nil))
    }

    func test_trigger_noMatch2() {
        // given a rule
        let rule = URLSessionTaskCaptureRule(rule: rule1)

        // it should not trigger for a request matches the url
        // but doesn't match the method
        var request = URLRequest(url: URL(string: "www.test.com/user/1234")!)
        request.httpMethod = "POST"

        XCTAssertFalse(rule.shouldTriggerFor(request: request, response: nil, error: nil))
    }

    func test_trigger_noMatch3() {
        // given a rule
        let rule = URLSessionTaskCaptureRule(rule: rule1)

        // it should not trigger for a request matches the url and method
        // doesnt match the status code
        let url = URL(string: "www.test.com/user/1234")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)

        XCTAssertFalse(rule.shouldTriggerFor(request: request, response: response, error: nil))
    }

    func test_trigger_noMatch4() {
        // given a rule
        let rule = URLSessionTaskCaptureRule(rule: rule3)

        // it should not trigger for a request matches on everything if the rule has expired
        let url = URL(string: "www.test.com/user/1234")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)

        XCTAssertFalse(rule.shouldTriggerFor(request: request, response: response, error: nil))
    }

    func test_trigger_match1() {
        // given a rule
        let rule = URLSessionTaskCaptureRule(rule: rule1)

        // it should trigger for a request matches on everything
        let url = URL(string: "www.test.com/user/1234")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)

        XCTAssert(rule.shouldTriggerFor(request: request, response: response, error: nil))
    }

    func test_trigger_match2() {
        // given a rule
        let rule = URLSessionTaskCaptureRule(rule: rule2)

        // it should trigger for a request matches on everything
        let url = URL(string: "www.test.com/test")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)
        let error = NSError(domain: "com.test.embrace", code: 1234)

        XCTAssert(rule.shouldTriggerFor(request: request, response: response, error: error))
    }

    func test_trigger_match3() {
        // given a rule
        let rule = URLSessionTaskCaptureRule(rule: rule1)

        // it should trigger for a request matches on everything
        let url = URL(string: "https://www.test.com/user/1234")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)

        XCTAssert(rule.shouldTriggerFor(request: request, response: response, error: nil))
    }
}
