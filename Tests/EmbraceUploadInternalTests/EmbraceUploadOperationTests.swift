//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import TestSupport
@testable import EmbraceUploadInternal

extension EmbraceUpload.ExponentialBackoff {
    static func withNoDelay() -> Self {
        .init(baseDelay: 0, maxDelay: 0)
    }
}

class EmbraceUploadOperationTests: XCTestCase {

    let testMetadataOptions = EmbraceUpload.MetadataOptions(
        apiKey: "apiKey",
        userAgent: "userAgent",
        deviceId: "12345678"
    )
    var urlSession: URLSession!
    var queue: DispatchQueue!

    override func setUpWithError() throws {
        let urlSessionconfig = URLSessionConfiguration.ephemeral
        urlSessionconfig.httpMaximumConnectionsPerHost = .max
        urlSessionconfig.protocolClasses = [EmbraceHTTPMock.self]

        self.urlSession = URLSession(configuration: urlSessionconfig)
        self.queue = .main
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
            queue: queue,
            metadataOptions: testMetadataOptions,
            endpoint: TestConstants.url,
            identifier: "id",
            data: Data(),
            attemptCount: 0
        ) { _, _ in
            expectation.fulfill()
        }

        operation.start()

        wait(for: [expectation], timeout: .defaultTimeout)

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
            queue: queue,
            metadataOptions: testMetadataOptions,
            endpoint: TestConstants.url,
            identifier: "id",
            data: Data(),
            attemptCount: 0
        ) { result, attemptCount in
            // then the operation should be successful
            XCTAssertEqual(result, .success)
            XCTAssertEqual(attemptCount, 1)

            expectation.fulfill()
        }

        operation.start()

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_unsuccessfulOperation_redirectStatusCode_shouldntBeRetriable() {
        // mock unsuccessful response
        EmbraceHTTPMock.mock(url: TestConstants.url, statusCode: 300)

        // given an upload operation
        let expectation = XCTestExpectation()

        let operation = EmbraceUploadOperation(
            urlSession: urlSession,
            queue: queue,
            metadataOptions: testMetadataOptions,
            endpoint: TestConstants.url,
            identifier: "id",
            data: Data(),
            attemptCount: 0
        ) { result, attemptCount in

            XCTAssertEqual(result, .failure(retriable: false))
            XCTAssertEqual(attemptCount, 1)

            expectation.fulfill()
        }

        operation.start()

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_cancelledOperation() {
        // mock successful response
        EmbraceHTTPMock.mock(url: TestConstants.url)

        // given a canceled upload operation
        let expectation = XCTestExpectation()

        let operation = EmbraceUploadOperation(
            urlSession: urlSession,
            queue: queue,
            metadataOptions: testMetadataOptions,
            endpoint: TestConstants.url,
            identifier: "id",
            data: Data(),
            attemptCount: 0
        ) { result, attemptCount in

            // then the operation should be canceled
            XCTAssertEqual(result, .failure(retriable: true))
            XCTAssertEqual(attemptCount, 0)

            expectation.fulfill()
        }

        operation.cancel()

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_onExecuting_whenReceivingNonRetryableError_shouldntRetry() {
        // mock error response with error that cannot be fixed with retries
        EmbraceHTTPMock.mock(url: TestConstants.url, response: .withData(Data(), statusCode: 404))

        // given an upload operation that errors
        let expectation = XCTestExpectation()

        let operation = EmbraceUploadOperation(
            urlSession: urlSession,
            queue: queue,
            metadataOptions: testMetadataOptions,
            endpoint: TestConstants.url,
            identifier: "id",
            data: Data(),
            attemptCount: 0
        ) { result, attemptCount in

            // then the operation should return the error
            XCTAssertEqual(result, .failure(retriable: false))
            XCTAssertEqual(attemptCount, 1)

            expectation.fulfill()
        }

        operation.start()

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_onExecuting_whenServerIsDown_shouldReturnARetriableFailure() {
        // mock error response
        EmbraceHTTPMock.mock(url: TestConstants.url, errorCode: 500)

        // given an upload operation that errors
        let expectation = XCTestExpectation()

        let operation = EmbraceUploadOperation(
            urlSession: urlSession,
            queue: queue,
            metadataOptions: testMetadataOptions,
            endpoint: TestConstants.url,
            identifier: "id",
            data: Data(),
            attemptCount: 0
        ) { result, attemptCount in

            XCTAssertEqual(result, .failure(retriable: true))
            XCTAssertEqual(attemptCount, 1)

            expectation.fulfill()
        }

        operation.start()

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_retryCount() {
        // mock error response
        EmbraceHTTPMock.mock(url: TestConstants.url, response: .withData(.init(), statusCode: 429))

        // given an upload operation that errors with a retry count of 1
        let expectation = XCTestExpectation()

        let operation = EmbraceUploadOperation(
            urlSession: urlSession,
            queue: queue,
            metadataOptions: testMetadataOptions,
            endpoint: TestConstants.url,
            identifier: "id",
            data: Data(),
            attemptCount: 1
        ) { result, attemptCount in

            // then the operation should return the error
            XCTAssertEqual(result, .failure(retriable: true))
            XCTAssertEqual(attemptCount, 2)

            expectation.fulfill()
        }

        operation.start()

        wait(for: [expectation], timeout: .defaultTimeout)

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

