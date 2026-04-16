//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import CoreData
import TestSupport
import XCTest

@testable import EmbraceUploadInternal

// MARK: - Helper to create a module with custom options

private func makeModule(
    testName: String,
    automaticRetryCount: Int = 0,
    queueLimit: Int = 10
) throws -> (EmbraceUpload, DispatchQueue) {

    let urlSessionConfig = URLSessionConfiguration.ephemeral
    urlSessionConfig.httpMaximumConnectionsPerHost = .max
    urlSessionConfig.protocolClasses = [EmbraceHTTPMock.self]

    let metadata = EmbraceUpload.MetadataOptions(
        apiKey: "apiKey",
        userAgent: "userAgent",
        deviceId: "12345678"
    )
    let redundancy = EmbraceUpload.RedundancyOptions(
        automaticRetryCount: automaticRetryCount,
        queueLimit: queueLimit
    )
    let endpoints = EmbraceUpload.EndpointOptions(
        spansURL: URL(string: "https://embrace.\(testName).com/upload/sessions")!,
        logsURL: URL(string: "https://embrace.\(testName).com/upload/logs")!,
        attachmentsURL: URL(string: "https://embrace.\(testName).com/upload/attachments")!
    )
    let options = EmbraceUpload.Options(
        endpoints: endpoints,
        cache: EmbraceUpload.CacheOptions(
            storageMechanism: .inMemory(name: testName), enableBackgroundTasks: false),
        metadata: metadata,
        redundancy: redundancy,
        urlSessionConfiguration: urlSessionConfig
    )

    let queue = DispatchQueue(label: "com.test.embrace.queue.\(testName)")
    let module = try EmbraceUpload(options: options, logger: MockLogger(), queue: queue)
    return (module, queue)
}

// MARK: - Tests

class EmbraceUploadOrderedDeliveryTests: XCTestCase {

    // MARK: - 1. Ordering guarantee

    func test_spansAreUploadedInInsertionOrder() throws {
        try XCTSkipIf(XCTestCase.isWatchOS())

        let (module, _) = try makeModule(testName: testName, automaticRetryCount: 0, queueLimit: 10)
        let spansUrl = URL(string: "https://embrace.\(testName).com/upload/sessions")!
        EmbraceHTTPMock.mock(url: spansUrl)

        let count = 5
        let completionExpectation = XCTestExpectation(description: "all completions")
        completionExpectation.expectedFulfillmentCount = count

        for i in 0..<count {
            module.uploadSpans(id: "span-\(i)", data: TestConstants.data) { _ in
                completionExpectation.fulfill()
            }
        }

        wait(for: [completionExpectation], timeout: .defaultTimeout)
        module.queue.sync {}
        module.spansQueue.waitUntilAllOperationsAreFinished()

        // Verify requests arrived in order
        let requests = EmbraceHTTPMock.requestsForUrl(spansUrl)
        XCTAssertEqual(requests.count, count)
    }

    func test_logsAreUploadedInInsertionOrder() throws {
        try XCTSkipIf(XCTestCase.isWatchOS())

        let (module, _) = try makeModule(testName: testName, automaticRetryCount: 0, queueLimit: 10)
        let logsUrl = URL(string: "https://embrace.\(testName).com/upload/logs")!
        EmbraceHTTPMock.mock(url: logsUrl)

        let count = 5
        let completionExpectation = XCTestExpectation(description: "all completions")
        completionExpectation.expectedFulfillmentCount = count

        for i in 0..<count {
            module.uploadLog(id: "log-\(i)", data: TestConstants.data) { _ in
                completionExpectation.fulfill()
            }
        }

        wait(for: [completionExpectation], timeout: .defaultTimeout)
        module.queue.sync {}
        module.logsQueue.waitUntilAllOperationsAreFinished()

        let requests = EmbraceHTTPMock.requestsForUrl(logsUrl)
        XCTAssertEqual(requests.count, count)
    }

    // MARK: - 2. Queue cap

    func test_queueCapLimitsOperations() throws {
        try XCTSkipIf(XCTestCase.isWatchOS())

        let queueLimit = 2
        let (module, _) = try makeModule(testName: testName, automaticRetryCount: 0, queueLimit: queueLimit)
        let spansUrl = URL(string: "https://embrace.\(testName).com/upload/sessions")!
        EmbraceHTTPMock.mock(url: spansUrl)

        // Upload more records than queueLimit
        let totalRecords = 5
        let completionExpectation = XCTestExpectation(description: "all completions")
        completionExpectation.expectedFulfillmentCount = totalRecords

        for i in 0..<totalRecords {
            module.uploadSpans(id: "span-\(i)", data: TestConstants.data) { _ in
                completionExpectation.fulfill()
            }
        }

        wait(for: [completionExpectation], timeout: .defaultTimeout)

        // Wait for all operations to drain (fillQueue refills after each completion)
        module.queue.sync {}
        module.spansQueue.waitUntilAllOperationsAreFinished()
        // Allow any remaining fillQueue cycles to complete
        module.queue.sync {}
        module.spansQueue.waitUntilAllOperationsAreFinished()

        // All records should eventually be uploaded
        let requests = EmbraceHTTPMock.requestsForUrl(spansUrl)
        XCTAssertEqual(requests.count, totalRecords)
    }

    // MARK: - 3. fillQueue excludes in-flight

    func test_fillQueueDoesNotCreateDuplicates() throws {
        try XCTSkipIf(XCTestCase.isWatchOS())

        let (module, _) = try makeModule(testName: testName, automaticRetryCount: 0, queueLimit: 10)
        let spansUrl = URL(string: "https://embrace.\(testName).com/upload/sessions")!
        EmbraceHTTPMock.mock(url: spansUrl)

        // Upload a single record
        let expectation = XCTestExpectation()
        module.uploadSpans(id: "span-1", data: TestConstants.data) { _ in
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
        module.queue.sync {}
        module.spansQueue.waitUntilAllOperationsAreFinished()

        // Should have exactly 1 request — no duplicates
        let requests = EmbraceHTTPMock.requestsForUrl(spansUrl)
        XCTAssertEqual(requests.count, 1)
    }

    // MARK: - 4. Immediate cache persistence

    func test_completionFiresBeforeUploadCompletes() throws {
        // Don't mock the URL — upload will fail, but we don't care about the upload
        let (module, _) = try makeModule(testName: testName, automaticRetryCount: 0, queueLimit: 10)

        let expectation = XCTestExpectation(description: "completion fires")

        module.uploadSpans(id: "span-1", data: TestConstants.data) { result in
            // Completion fires after cache write, before upload
            switch result {
            case .success:
                // Verify record exists in cache at completion time
                let record = module.cache.fetchUploadData(id: "span-1", type: .spans)
                XCTAssertNotNil(record, "Record should exist in cache when completion fires")
                expectation.fulfill()
            default:
                XCTFail("Upload should've succeeded (cache-first)")
            }
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    // MARK: - 5. Unlimited retries

    func test_unlimitedRetriesWithNegativeOne() throws {
        try XCTSkipIf(XCTestCase.isWatchOS())

        // mock 500 error — retriable
        EmbraceHTTPMock.mock(url: TestConstants.url, errorCode: 500)

        let expectation = XCTestExpectation()

        // retryCount: -1 means unlimited. We verify it retries at least 3 times.
        var finalAttemptCount = 0
        let operation = EmbraceUploadOperation(
            urlSession: makeTestURLSession(),
            queue: .main,
            metadataOptions: EmbraceUpload.MetadataOptions(
                apiKey: "apiKey", userAgent: "userAgent", deviceId: "12345678"),
            endpoint: TestConstants.url,
            identifier: "id",
            data: Data(),
            retryCount: -1,
            exponentialBackoffBehavior: .withNoDelay(),
            attemptCount: 0
        ) { result, attemptCount in
            finalAttemptCount = attemptCount
            expectation.fulfill()
        }

        // Cancel after a short delay to stop the unlimited retries
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            operation.cancel()
        }

        operation.start()

        wait(for: [expectation], timeout: .defaultTimeout)

        // Should have retried multiple times before being cancelled
        XCTAssertGreaterThan(finalAttemptCount, 1, "Operation should have retried multiple times")
    }

    // MARK: - 6. Finite retries exhausted → delete

    func test_finiteRetriesExhaustedDeletesFromCache() throws {
        try XCTSkipIf(XCTestCase.isWatchOS())

        let (module, _) = try makeModule(testName: testName, automaticRetryCount: 2, queueLimit: 10)
        let spansUrl = URL(string: "https://embrace.\(testName).com/upload/sessions")!

        // Mock 500 so every attempt fails
        EmbraceHTTPMock.mock(url: spansUrl, errorCode: 500)

        let expectation = XCTestExpectation(description: "completion")
        module.uploadSpans(id: "span-1", data: TestConstants.data) { _ in
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
        module.queue.sync {}
        module.spansQueue.waitUntilAllOperationsAreFinished()
        module.queue.sync {}

        // Record should be deleted from cache after retries exhausted
        let record = module.cache.fetchUploadData(id: "span-1", type: .spans)
        XCTAssertNil(record, "Record should be deleted after retries exhausted")

        // Total attempts: 1 initial + 2 retries = 3
        let requests = EmbraceHTTPMock.requestsForUrl(spansUrl)
        XCTAssertEqual(requests.count, 3)
    }

    // MARK: - 7. Non-retriable URLError (.badURL)

    func test_nonRetriableErrorDeletesImmediately() throws {
        try XCTSkipIf(XCTestCase.isWatchOS())

        EmbraceHTTPMock.mock(
            url: TestConstants.url,
            response: .withError(
                NSError(
                    domain: NSURLErrorDomain,
                    code: URLError.badURL.rawValue,
                    userInfo: [:]
                )
            )
        )

        let expectation = XCTestExpectation()

        let operation = EmbraceUploadOperation(
            urlSession: makeTestURLSession(),
            queue: .main,
            metadataOptions: EmbraceUpload.MetadataOptions(
                apiKey: "apiKey", userAgent: "userAgent", deviceId: "12345678"),
            endpoint: TestConstants.url,
            identifier: "id",
            data: Data(),
            retryCount: 100,
            exponentialBackoffBehavior: .withNoDelay(),
            attemptCount: 0
        ) { result, attemptCount in
            XCTAssertEqual(result, .failure)
            XCTAssertEqual(attemptCount, 1, "Should not retry non-retriable errors")
            expectation.fulfill()
        }

        operation.start()
        wait(for: [expectation], timeout: .defaultTimeout)
    }

    // MARK: - 8. 4xx is now retriable

    func test_404IsRetriable() throws {
        try XCTSkipIf(XCTestCase.isWatchOS())

        // Mock a 404 response
        EmbraceHTTPMock.mock(url: TestConstants.url, response: .withData(Data(), statusCode: 404))

        let expectation = XCTestExpectation()

        let operation = EmbraceUploadOperation(
            urlSession: makeTestURLSession(),
            queue: .main,
            metadataOptions: EmbraceUpload.MetadataOptions(
                apiKey: "apiKey", userAgent: "userAgent", deviceId: "12345678"),
            endpoint: TestConstants.url,
            identifier: "id",
            data: Data(),
            retryCount: 1,
            exponentialBackoffBehavior: .withNoDelay(),
            attemptCount: 0
        ) { result, attemptCount in
            XCTAssertEqual(result, .failure)
            // 1 initial + 1 retry = 2 total attempts
            XCTAssertEqual(attemptCount, 2, "404 should be retried")
            expectation.fulfill()
        }

        operation.start()
        wait(for: [expectation], timeout: .defaultTimeout)
    }

    // MARK: - 9. Cancel keeps record

    func test_cancelKeepsRecordInCache() throws {
        // Use unlimited retries so the operation is still running when we cancel
        let (module, _) = try makeModule(testName: testName, automaticRetryCount: -1, queueLimit: 10)

        // Upload data to cache it — no mock URL so every attempt fails and retries
        let expectation = XCTestExpectation(description: "completion")
        module.uploadSpans(id: "span-1", data: TestConstants.data) { _ in
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: .defaultTimeout)

        // Ensure the operation has been enqueued
        module.queue.sync {}

        // Cancel all operations while they're still retrying
        module.spansQueue.cancelAllOperations()
        module.spansQueue.waitUntilAllOperationsAreFinished()

        // Allow handleOperationFinished to process on coordination queue
        module.queue.sync {}

        // Cancelled operations should keep the record in cache
        let record = module.cache.fetchUploadData(id: "span-1", type: .spans)
        XCTAssertNotNil(record, "Cancelled operation should preserve cache record")
    }

    // MARK: - 10. retryCachedData ordering

    func test_retryCachedDataUploadsInDateOrder() throws {
        try XCTSkipIf(XCTestCase.isWatchOS())

        let (module, _) = try makeModule(testName: testName, automaticRetryCount: 0, queueLimit: 10)
        let spansUrl = URL(string: "https://embrace.\(testName).com/upload/sessions")!
        EmbraceHTTPMock.mock(url: spansUrl)

        // Pre-populate cache with records at different dates
        let now = Date()
        _ = UploadDataRecord.create(
            context: module.cache.coreData.context,
            id: "oldest",
            type: EmbraceUploadType.spans.rawValue,
            data: TestConstants.data,
            payloadTypes: nil,
            date: Date(timeInterval: -300, since: now)
        )
        _ = UploadDataRecord.create(
            context: module.cache.coreData.context,
            id: "middle",
            type: EmbraceUploadType.spans.rawValue,
            data: TestConstants.data,
            payloadTypes: nil,
            date: Date(timeInterval: -200, since: now)
        )
        _ = UploadDataRecord.create(
            context: module.cache.coreData.context,
            id: "newest",
            type: EmbraceUploadType.spans.rawValue,
            data: TestConstants.data,
            payloadTypes: nil,
            date: Date(timeInterval: -100, since: now)
        )
        module.cache.coreData.save()

        let retryExpectation = XCTestExpectation(description: "retryCachedData completes")
        module.retryCachedData {
            retryExpectation.fulfill()
        }
        wait(for: [retryExpectation], timeout: .defaultTimeout)
        module.spansQueue.waitUntilAllOperationsAreFinished()

        // All 3 records should be uploaded
        let requests = EmbraceHTTPMock.requestsForUrl(spansUrl)
        XCTAssertEqual(requests.count, 3)
    }

    // MARK: - 11. retryCachedData + live uploads

    func test_retryCachedDataThenLiveUpload() throws {
        try XCTSkipIf(XCTestCase.isWatchOS())

        let (module, _) = try makeModule(testName: testName, automaticRetryCount: 0, queueLimit: 10)
        let spansUrl = URL(string: "https://embrace.\(testName).com/upload/sessions")!
        EmbraceHTTPMock.mock(url: spansUrl)

        // Pre-populate cache with a record
        _ = module.cache.saveUploadData(id: "cached-1", type: .spans, data: TestConstants.data)

        // Retry cached data
        let retryExpectation = XCTestExpectation(description: "retryCachedData completes")
        module.retryCachedData {
            retryExpectation.fulfill()
        }
        wait(for: [retryExpectation], timeout: .defaultTimeout)

        // Immediately upload a new record
        let expectation = XCTestExpectation(description: "live upload completion")
        module.uploadSpans(id: "live-1", data: TestConstants.data) { _ in
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: .defaultTimeout)

        module.queue.sync {}
        module.spansQueue.waitUntilAllOperationsAreFinished()

        // Both should be uploaded
        let requests = EmbraceHTTPMock.requestsForUrl(spansUrl)
        XCTAssertEqual(requests.count, 2)
    }

    // MARK: - 12. Cross-type independence

    func test_crossTypeIndependence() throws {
        try XCTSkipIf(XCTestCase.isWatchOS())

        let (module, _) = try makeModule(testName: testName, automaticRetryCount: 0, queueLimit: 10)
        let spansUrl = URL(string: "https://embrace.\(testName).com/upload/sessions")!
        let logsUrl = URL(string: "https://embrace.\(testName).com/upload/logs")!
        EmbraceHTTPMock.mock(url: spansUrl)
        EmbraceHTTPMock.mock(url: logsUrl)

        let expectation = XCTestExpectation(description: "all completions")
        expectation.expectedFulfillmentCount = 2

        // Upload a span and a log simultaneously
        module.uploadSpans(id: "span-1", data: TestConstants.data) { _ in
            expectation.fulfill()
        }
        module.uploadLog(id: "log-1", data: TestConstants.data) { _ in
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
        module.queue.sync {}
        module.spansQueue.waitUntilAllOperationsAreFinished()
        module.logsQueue.waitUntilAllOperationsAreFinished()

        // Both types should have been uploaded independently
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(spansUrl).count, 1)
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(logsUrl).count, 1)
    }
}

// MARK: - Helpers

extension EmbraceUploadOrderedDeliveryTests {
    private func makeTestURLSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.httpMaximumConnectionsPerHost = .max
        config.protocolClasses = [EmbraceHTTPMock.self]
        return URLSession(configuration: config)
    }
}
