//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import TestSupport
@testable import EmbraceUpload

class EmbraceUploadOperationTests: XCTestCase {

    let testMetadataOptions = EmbraceUpload.MetadataOptions(apiKey: "apiKey", userAgent: "userAgent", deviceId: "12345678")
    var urlSession: URLSession!

    override func setUpWithError() throws {
        let urlSessionconfig = URLSessionConfiguration.ephemeral
        urlSessionconfig.protocolClasses = [EmbraceHTTPMock.self]

        self.urlSession = URLSession(configuration: urlSessionconfig)

        EmbraceHTTPMock.setUp()
    }

    override func tearDownWithError() throws {

    }

    func test_genericRequestHeaders() {
        // mock successful response
        EmbraceHTTPMock.mock(url: TestConstants.url)

        // given an upload operation
        let expectation = XCTestExpectation()

        let operation = EmbraceUploadOperation(
            urlSession: urlSession,
            metadataOptions: testMetadataOptions,
            endpoint: TestConstants.url,
            identifier: "id",
            data: Data(),
            retryCount: 0,
            attemptCount: 0
        ) { _, _, _ in
            expectation.fulfill()
        }

        operation.start()

        wait(for: [expectation], timeout: TestConstants.defaultTimeout)

        // then the request should have the correct headers
        guard let request = EmbraceHTTPMock.requestsForUrl(TestConstants.url).first else {
            XCTAssert(false, "Invalid request!")
            return
        }

        XCTAssertEqual(request.httpMethod, "POST")

        guard let headers = request.allHTTPHeaderFields else {
            XCTAssert(false, "Invalid request headers!")
            return
        }

        XCTAssertEqual(headers["Accept"], "application/json")
        XCTAssertEqual(headers["Content-Type"], "application/json")
        XCTAssertEqual(headers["User-Agent"], testMetadataOptions.userAgent)
        XCTAssertEqual(headers["Content-Encoding"], "gzip")
        XCTAssertEqual(headers["X-EM-AID"], testMetadataOptions.apiKey)
        XCTAssertEqual(headers["X-EM-DID"], testMetadataOptions.deviceId)
        XCTAssertNil(headers["x-emb-retry-count"])
    }

    func test_successfulOperation() {
        // mock successful response
        EmbraceHTTPMock.mock(url: TestConstants.url)

        // given an upload operation
        let expectation = XCTestExpectation()

        let operation = EmbraceUploadOperation(
            urlSession: urlSession,
            metadataOptions: testMetadataOptions,
            endpoint: TestConstants.url,
            identifier: "id",
            data: Data(),
            retryCount: 0,
            attemptCount: 0
        ) { cancelled, attemptCount, error in

            // then the operation should be successful
            XCTAssertFalse(cancelled)
            XCTAssertEqual(attemptCount, 1)
            XCTAssertNil(error)

            expectation.fulfill()
        }

        operation.start()

        wait(for: [expectation], timeout: TestConstants.defaultTimeout)
    }

    func test_cancelledOperation() {
        // mock successful response
        EmbraceHTTPMock.mock(url: TestConstants.url)

        // given a canceled upload operation
        let expectation = XCTestExpectation()

        let operation = EmbraceUploadOperation(
            urlSession: urlSession,
            metadataOptions: testMetadataOptions,
            endpoint: TestConstants.url,
            identifier: "id",
            data: Data(),
            retryCount: 0,
            attemptCount: 0
        ) { cancelled, attemptCount, error in

            // then the operation should be canceled
            XCTAssert(cancelled)
            XCTAssertEqual(attemptCount, 0)
            XCTAssertNil(error)

            expectation.fulfill()
        }

        operation.cancel()

        wait(for: [expectation], timeout: TestConstants.defaultTimeout)
    }

    func test_failedOperation() {
        // mock error response
        EmbraceHTTPMock.mock(url: TestConstants.url, errorCode: 500)

        // given an upload operation that errors
        let expectation = XCTestExpectation()

        let operation = EmbraceUploadOperation(
            urlSession: urlSession,
            metadataOptions: testMetadataOptions,
            endpoint: TestConstants.url,
            identifier: "id",
            data: Data(),
            retryCount: 0,
            attemptCount: 0
        ) { cancelled, attemptCount, error in

            // then the operation should return the error
            XCTAssertFalse(cancelled)
            XCTAssertEqual(attemptCount, 1)
            XCTAssertNotNil(error)

            expectation.fulfill()
        }

        operation.start()

        wait(for: [expectation], timeout: TestConstants.defaultTimeout)
    }

    func test_retryCount() {
        // mock error response
        EmbraceHTTPMock.mock(url: TestConstants.url, errorCode: 500)

        // given an upload operation that errors with a retry count of 1
        let expectation = XCTestExpectation()

        let operation = EmbraceUploadOperation(
            urlSession: urlSession,
            metadataOptions: testMetadataOptions,
            endpoint: TestConstants.url,
            identifier: "id",
            data: Data(),
            retryCount: 1,
            attemptCount: 0
        ) { cancelled, attemptCount, error in

            // then the operation should return the error
            XCTAssertFalse(cancelled)
            XCTAssertEqual(attemptCount, 2)
            XCTAssertNotNil(error)

            expectation.fulfill()
        }

        operation.start()

        wait(for: [expectation], timeout: TestConstants.defaultTimeout)

        // then the request should have the correct headers
        guard let request = EmbraceHTTPMock.requestsForUrl(TestConstants.url).last else {
            XCTAssert(false, "Invalid request!")
            return
        }

        XCTAssertEqual(request.httpMethod, "POST")

        guard let headers = request.allHTTPHeaderFields else {
            XCTAssert(false, "Invalid request headers!")
            return
        }

        XCTAssertEqual(headers["x-emb-retry-count"], "1")
    }
}
