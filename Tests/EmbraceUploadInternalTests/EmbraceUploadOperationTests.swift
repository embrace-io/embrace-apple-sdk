//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import TestSupport
import XCTest

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

    func test_genericRequestHeaders() throws {
        try XCTSkipIf(XCTestCase.isWatchOS(), "Unavailable on WatchOS")
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
            retryCount: 0,
            exponentialBackoffBehavior: .init(),
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

    func test_successfulOperation() throws {
        try XCTSkipIf(XCTestCase.isWatchOS(), "Unavailable on WatchOS")

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
            retryCount: 5,
            exponentialBackoffBehavior: .init(),
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

    func test_unsuccessfulOperation_redirectStatusCode_shouldntBeRetriable() throws {
        try XCTSkipIf(XCTestCase.isWatchOS(), "Unavailable on WatchOS")

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
            retryCount: 5,
            exponentialBackoffBehavior: .init(),
            attemptCount: 0
        ) { result, attemptCount in

            XCTAssertEqual(result, .failure(retriable: false))
            XCTAssertEqual(attemptCount, 1)

            expectation.fulfill()
        }

        operation.start()

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_unsuccessfulOperation_nonRetriableError_shouldntBeRetriable() throws {
        try XCTSkipIf(XCTestCase.isWatchOS(), "Unavailable on WatchOS")

        // mock unsuccessful response with unretriable URLError
        EmbraceHTTPMock.mock(
            url: TestConstants.url,
            response: .withError(
                NSError(
                    domain: NSURLErrorDomain,
                    code: URLError.unsupportedURL.rawValue,
                    userInfo: [:]
                )
            )
        )

        // given an upload operation
        let expectation = XCTestExpectation()

        let operation = EmbraceUploadOperation(
            urlSession: urlSession,
            queue: queue,
            metadataOptions: testMetadataOptions,
            endpoint: TestConstants.url,
            identifier: "id",
            data: Data(),
            retryCount: 5,
            exponentialBackoffBehavior: .init(),
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
            retryCount: 5,
            exponentialBackoffBehavior: .init(),
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

    func test_onExecuting_whenReceivingNonRetryableError_shouldntRetry() throws {
        try XCTSkipIf(XCTestCase.isWatchOS(), "Unavailable on WatchOS")

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
            retryCount: 100,
            exponentialBackoffBehavior: .init(),
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

    func test_onExecuting_whenServerIsDown_shouldReturnARetriableFailure() throws {
        try XCTSkipIf(XCTestCase.isWatchOS(), "Unavailable on WatchOS")

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
            retryCount: 0,
            exponentialBackoffBehavior: .init(),
            attemptCount: 0
        ) { result, attemptCount in

            XCTAssertEqual(result, .failure(retriable: true))
            XCTAssertEqual(attemptCount, 1)

            expectation.fulfill()
        }

        operation.start()

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_onReceivingServerIssuesStatusCode_shouldRetryRequestTheAmountOfRetryCounts() throws {
        try XCTSkipIf(XCTestCase.isWatchOS(), "Unavailable on WatchOS")

        // mock error response
        let serverSideErrorStatusCode = try XCTUnwrap((500...599).map { $0 }.randomElement())
        EmbraceHTTPMock.mock(
            url: TestConstants.url,
            response: .withData(
                Data(),
                statusCode: serverSideErrorStatusCode
            )
        )

        // given an upload operation that errors with a retry count of 1
        let expectation = XCTestExpectation()

        let operation = EmbraceUploadOperation(
            urlSession: urlSession,
            queue: queue,
            metadataOptions: testMetadataOptions,
            endpoint: TestConstants.url,
            identifier: "id",
            data: Data(),
            retryCount: 1,
            exponentialBackoffBehavior: .withNoDelay(),
            attemptCount: 0
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

    func test_onReceivingTooManyRequestsStatusCode_shouldRetryRequestTheAmountOfRetryCounts() throws {
        try XCTSkipIf(XCTestCase.isWatchOS(), "Unavailable on WatchOS")

        // mock error response
        EmbraceHTTPMock.mock(
            url: TestConstants.url,
            response: .withData(
                Data(),
                statusCode: 429
            )
        )

        // given an upload operation that errors with a retry count of 1
        let expectation = XCTestExpectation()

        let operation = EmbraceUploadOperation(
            urlSession: urlSession,
            queue: queue,
            metadataOptions: testMetadataOptions,
            endpoint: TestConstants.url,
            identifier: "id",
            data: Data(),
            retryCount: 3,
            exponentialBackoffBehavior: .withNoDelay(),
            attemptCount: 0
        ) { result, attemptCount in

            // then the operation should return the error
            XCTAssertEqual(result, .failure(retriable: true))
            XCTAssertEqual(attemptCount, 4)

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

        XCTAssertEqual(headers["x-emb-retry-count"], "3")
    }

    func test_onErrorWithRetryAfterHeader_shouldAppendToTheActualRetryDelay() throws {
        try XCTSkipIf(XCTestCase.isWatchOS(), "Unavailable on WatchOS")

        let retryAfterDelay = 1
        // mock unsuccessful response with retry after header
        EmbraceHTTPMock.mock(
            url: TestConstants.url,
            response: .withData(
                .init(),
                statusCode: 429,
                headers: ["Retry-After": "\(retryAfterDelay)"]
            )
        )
        // given an upload operation that errors with a retry count of 1
        let expectation = XCTestExpectation()

        let operation = EmbraceUploadOperation(
            urlSession: urlSession,
            queue: queue,
            metadataOptions: testMetadataOptions,
            endpoint: TestConstants.url,
            identifier: "id",
            data: Data(),
            retryCount: 1,
            exponentialBackoffBehavior: .withNoDelay(),
            attemptCount: 0
        ) { result, attemptCount in

            // then the operation should return the error
            XCTAssertEqual(result, .failure(retriable: true))
            XCTAssertEqual(attemptCount, 2)

            expectation.fulfill()
        }

        operation.start()

        wait(for: [expectation], timeout: .defaultTimeout + Double(retryAfterDelay))

        // then the request should have the correct headers
        guard let request = EmbraceHTTPMock.requestsForUrl(TestConstants.url).last else {
            XCTAssert(false, "Invalid request!")
            return
        }

        guard let headers = request.allHTTPHeaderFields else {
            XCTAssert(false, "Invalid request headers!")
            return
        }

        XCTAssertEqual(headers["x-emb-retry-count"], "1")
    }
}
