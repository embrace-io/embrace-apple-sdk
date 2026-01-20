//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceStorageInternal
import TestSupport
import XCTest

@testable import EmbraceConfigInternal
@testable import EmbraceCore

// swiftlint:disable force_cast

class EncryptedNetworkPayloadTests: XCTestCase {

    let startTime = Date(timeIntervalSince1970: 100)
    let endTime = Date(timeIntervalSince1970: 105)

    func test_invalidValues() {
        // given a new payload for the given invalid parameters
        let payload = EncryptedNetworkPayload(
            request: nil,
            response: nil,
            data: nil,
            error: nil,
            startTime: nil,
            endTime: nil,
            matchedUrl: "",
            sessionId: nil
        )

        // then its not created
        XCTAssertNil(payload)
    }

    func getTestPayload() -> EncryptedNetworkPayload? {
        let url = URL(string: "www.test.com/user/1234?q=test")!

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.httpBody = "1234".data(using: .utf8)
        request.allHTTPHeaderFields = ["testKey": "testValue"]

        let response = HTTPURLResponse(
            url: url,
            statusCode: 500,
            httpVersion: nil,
            headerFields: ["testKey": "testValue"]
        )
        let error = NSError(
            domain: "com.test.embrace",
            code: 1234,
            userInfo: [NSLocalizedDescriptionKey: "test message"]
        )

        return EncryptedNetworkPayload(
            request: request,
            response: response,
            data: "5678".data(using: .utf8),
            error: error,
            startTime: startTime,
            endTime: endTime,
            matchedUrl: "www.test.com/user/*",
            sessionId: TestConstants.sessionId
        )
    }

    func test_properties() {
        // given a new payload for the given parameters
        let payload = getTestPayload()

        // the the values are correct
        XCTAssertEqual(payload!.url, "www.test.com/user/1234?q=test")
        XCTAssertEqual(payload!.httpMethod, "GET")
        XCTAssertEqual(payload!.startTime, startTime.nanosecondsSince1970Truncated)
        XCTAssertEqual(payload!.endTime, endTime.nanosecondsSince1970Truncated)
        XCTAssertEqual(payload!.matchedUrl, "www.test.com/user/*")
        XCTAssertEqual(payload!.sessionId, TestConstants.sessionId.stringValue)
        XCTAssertEqual(payload!.requestBody, "1234")
        XCTAssertEqual(payload!.requestBodySize, 4)
        XCTAssertEqual(payload!.requestQuery, "q=test")
        XCTAssertEqual(payload!.requestHeaders, ["testKey": "testValue"])
        XCTAssertEqual(payload!.responseBody, "5678")
        XCTAssertEqual(payload!.responseBodySize, 4)
        XCTAssertEqual(payload!.responseHeaders, ["testKey": "testValue"])
        XCTAssertEqual(payload!.responseStatus, 500)
        XCTAssertEqual(payload!.errorMessage, "test message")
    }

    func test_json() throws {
        // given a new payload for the given parameters
        let payload = getTestPayload()

        // when encoding it to json format
        let data = try JSONEncoder().encode(payload)
        let dict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]

        // then the json is correct
        XCTAssertEqual(dict!["url"] as! String, "www.test.com/user/1234?q=test")
        XCTAssertEqual(dict!["http-method"] as! String, "GET")
        #if os(watchOS)
            XCTAssertEqual(dict!["start-time"] as! Int64, startTime.nanosecondsSince1970Truncated)
            XCTAssertEqual(dict!["end-time"] as! Int64, endTime.nanosecondsSince1970Truncated)
        #else
            XCTAssertEqual(dict!["start-time"] as! Int, startTime.nanosecondsSince1970Truncated)
            XCTAssertEqual(dict!["end-time"] as! Int, endTime.nanosecondsSince1970Truncated)
        #endif
        XCTAssertEqual(dict!["matched-url"] as! String, "www.test.com/user/*")
        XCTAssertEqual(dict!["session-id"] as! String, TestConstants.sessionId.stringValue)
        XCTAssertEqual(dict!["request-body"] as! String, "1234")
        XCTAssertEqual(dict!["request-body-size"] as! Int, 4)
        XCTAssertEqual(dict!["request-query"] as! String, "q=test")
        XCTAssertEqual(dict!["request-headers"] as! [String: String], ["testKey": "testValue"])
        XCTAssertEqual(dict!["response-body"] as! String, "5678")
        XCTAssertEqual(dict!["response-body-size"] as! Int, 4)
        XCTAssertEqual(dict!["response-headers"] as! [String: String], ["testKey": "testValue"])
        XCTAssertEqual(dict!["response-status"] as! Int, 500)
        XCTAssertEqual(dict!["error-message"] as! String, "test message")
    }

    func test_encryption() throws {
        // given a new payload for the given parameters
        let payload = getTestPayload()

        // when ecrypting with a valid public key
        let result = payload?.encrypted(withKey: TestConstants.rsaSanitizedPublicKey)

        // then the encryption is succesful
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.mechanism, "hybrid")
        XCTAssertEqual(result!.payloadAlgorithm, "aes-256-cbc")
        XCTAssertEqual(result!.keyAlgorithm, "RSA.PKCS1")
    }

    func test_encryption_invalidKey() throws {
        // given a new payload for the given parameters
        let payload = getTestPayload()

        // when ecrypting with an invalid public key
        let result = payload?.encrypted(withKey: TestConstants.rsaPublicKey)

        // then the encryption fails
        XCTAssertNil(result)
    }
}

// swiftlint:enable force_cast
