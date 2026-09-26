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
    queueLimit: Int = 10,
    exponentialBackoffBehavior: EmbraceUpload.ExponentialBackoff = .withNoDelay()
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
        queueLimit: queueLimit,
        retryOnInternetConnected: false,
        exponentialBackoffBehavior: exponentialBackoffBehavior
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

    override func setUp() {
        super.setUp()
        // EmbraceHTTPMock state is process-wide; reset between methods.
        EmbraceHTTPMock.clearRequests()
    }

    // MARK: - 1. Ordering guarantee

    func test_spansAreUploadedInInsertionOrder() throws {
        try XCTSkipIf(XCTestCase.isWatchOS())

        let (module, _) = try makeModule(testName: testName, automaticRetryCount: 0, queueLimit: 10)
        let spansUrl = URL(string: "https://embrace.\(testName).com/upload/sessions")!
        EmbraceHTTPMock.mock(url: spansUrl)

        let count = 5
        var completions = 0

        for i in 0..<count {
            let data = "span-\(i)".data(using: .utf8)!
            module.uploadSpans(id: "span-\(i)", data: data) { _ in
                completions += 1
            }
        }

        module.waitForAllWork()
        XCTAssertEqual(completions, count)

        // Verify requests arrived in order
        let requests = EmbraceHTTPMock.requestsForUrl(spansUrl)
        XCTAssertEqual(requests.count, count)
        let bodies = EmbraceHTTPMock.requestBodiesForUrl(spansUrl)
        XCTAssertEqual(bodies.count, count)
        for i in 0..<count {
            let expected = "span-\(i)".data(using: .utf8)!
            XCTAssertEqual(bodies[i], expected, "span request \(i) out of order")
        }
    }

    func test_logsAreUploadedInInsertionOrder() throws {
        try XCTSkipIf(XCTestCase.isWatchOS())

        let (module, _) = try makeModule(testName: testName, automaticRetryCount: 0, queueLimit: 10)
        let logsUrl = URL(string: "https://embrace.\(testName).com/upload/logs")!
        EmbraceHTTPMock.mock(url: logsUrl)

        let count = 5
        var completions = 0

        for i in 0..<count {
            let data = "log-\(i)".data(using: .utf8)!
            module.uploadLog(id: "log-\(i)", data: data) { _ in
                completions += 1
            }
        }

        module.waitForAllWork()
        XCTAssertEqual(completions, count)

        let requests = EmbraceHTTPMock.requestsForUrl(logsUrl)
        XCTAssertEqual(requests.count, count)
        let bodies = EmbraceHTTPMock.requestBodiesForUrl(logsUrl)
        XCTAssertEqual(bodies.count, count)
        for i in 0..<count {
            let expected = "log-\(i)".data(using: .utf8)!
            XCTAssertEqual(bodies[i], expected, "log request \(i) out of order")
        }
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
        var completions = 0

        for i in 0..<totalRecords {
            module.uploadSpans(id: "span-\(i)", data: TestConstants.data) { _ in
                completions += 1
            }
        }

        // waitForAllWork keeps draining until the refills that each finished upload triggers have
        // also finished, so every record has been uploaded when it returns.
        module.waitForAllWork()
        XCTAssertEqual(completions, totalRecords)
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(spansUrl).count, totalRecords)
    }

    // MARK: - 3. fillQueue excludes in-flight

    func test_fillQueueDoesNotCreateDuplicates() throws {
        try XCTSkipIf(XCTestCase.isWatchOS())

        let (module, _) = try makeModule(testName: testName, automaticRetryCount: 0, queueLimit: 10)
        let spansUrl = URL(string: "https://embrace.\(testName).com/upload/sessions")!
        EmbraceHTTPMock.mock(url: spansUrl)

        // Upload a single record
        var completed = false
        module.uploadSpans(id: "span-1", data: TestConstants.data) { _ in
            completed = true
        }

        module.waitForAllWork()
        XCTAssertTrue(completed)

        // Should have exactly 1 request — no duplicates
        let requests = EmbraceHTTPMock.requestsForUrl(spansUrl)
        XCTAssertEqual(requests.count, 1)
    }

    // MARK: - 4. Immediate cache persistence

    func test_completionFiresBeforeUploadCompletes() throws {
        // Don't mock the URL — upload will fail, but we don't care about the upload
        let (module, _) = try makeModule(testName: testName, automaticRetryCount: 0, queueLimit: 10)

        var completed = false

        module.uploadSpans(id: "span-1", data: TestConstants.data) { result in
            // Completion fires after cache write, before upload
            switch result {
            case .success:
                // Verify record exists in cache at completion time
                let record = module.cache.fetchUploadData(id: "span-1", type: .spans)
                XCTAssertNotNil(record, "Record should exist in cache when completion fires")
                completed = true
            default:
                XCTFail("Upload should've succeeded (cache-first)")
            }
        }

        // The completion runs on the coordination queue
        module.queue.sync {}
        XCTAssertTrue(completed)

        module.waitForAllWork()
    }

    // MARK: - 5. Unlimited retries

    func test_unlimitedRetriesWithNegativeOne() throws {
        try XCTSkipIf(XCTestCase.isWatchOS())

        // mock 500 error — retriable.
        // The cancel below counts the requests to this URL, so no other test can share it. A
        // request from another test's operation that is still retrying would throw the count off.
        let url = URL(string: "https://embrace.\(testName).com/upload")!
        EmbraceHTTPMock.mock(url: url, errorCode: 500)

        let expectation = XCTestExpectation()

        // retryCount: -1 means unlimited. We verify it keeps retrying until it is cancelled.
        var finalAttemptCount = 0
        let operation = EmbraceUploadOperation(
            urlSession: makeTestURLSession(),
            queue: .main,
            metadataOptions: EmbraceUpload.MetadataOptions(
                apiKey: "apiKey", userAgent: "userAgent", deviceId: "12345678"),
            endpoint: url,
            identifier: "id",
            data: Data(),
            retryCount: -1,
            exponentialBackoffBehavior: .withNoDelay(),
            attemptCount: 0
        ) { result, attemptCount in
            finalAttemptCount = attemptCount
            expectation.fulfill()
        }

        // Cancel during the 3rd attempt to stop the unlimited retries
        EmbraceHTTPMock.onRequest(to: url) {
            if EmbraceHTTPMock.requestsForUrl(url).count == 3 {
                operation.cancel()
            }
        }

        operation.start()

        wait(for: [expectation], timeout: .defaultTimeout)

        // Should have retried twice before being cancelled
        XCTAssertEqual(finalAttemptCount, 3, "Operation should have retried multiple times")
    }

    // MARK: - 6. Finite retries exhausted → delete

    func test_finiteRetriesExhaustedDeletesFromCache() throws {
        try XCTSkipIf(XCTestCase.isWatchOS())

        let (module, _) = try makeModule(testName: testName, automaticRetryCount: 2, queueLimit: 10)
        let spansUrl = URL(string: "https://embrace.\(testName).com/upload/sessions")!

        // Mock 500 so every attempt fails
        EmbraceHTTPMock.mock(url: spansUrl, errorCode: 500)

        var completed = false
        module.uploadSpans(id: "span-1", data: TestConstants.data) { _ in
            completed = true
        }

        module.waitForAllWork()
        XCTAssertTrue(completed)

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
        let (module, _) = try makeModule(
            testName: testName,
            automaticRetryCount: -1,
            queueLimit: 10,
            exponentialBackoffBehavior: .init()
        )

        // Upload data to cache it — no mock URL so every attempt fails and retries
        var completed = false
        module.uploadSpans(id: "span-1", data: TestConstants.data) { _ in
            completed = true
        }

        // Ensure the completion has fired and the operation has been enqueued
        module.queue.sync {}
        XCTAssertTrue(completed)

        // Cancel all operations while they're still retrying
        module.spansQueue.cancelAllOperations()

        // Allow handleOperationFinished to process on coordination queue
        module.queue.sync {}

        // Cancelled operations should keep the record in cache
        let record = module.cache.fetchUploadData(id: "span-1", type: .spans)
        XCTAssertNotNil(record, "Cancelled operation should preserve cache record")

        // handleOperationFinished refilled the queue with a new unlimited-retry operation for the
        // kept record. Delete the record before cancelling it, so the refill that follows finds
        // nothing and no operation keeps retrying into later tests.
        module.queue.sync {
            module.cache.deleteUploadData(id: "span-1", type: .spans)
        }
        module.spansQueue.cancelAllOperations()
        module.waitForAllWork()
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
            data: Data("oldest".utf8),
            payloadTypes: nil,
            date: Date(timeInterval: -300, since: now)
        )
        _ = UploadDataRecord.create(
            context: module.cache.coreData.context,
            id: "middle",
            type: EmbraceUploadType.spans.rawValue,
            data: Data("middle".utf8),
            payloadTypes: nil,
            date: Date(timeInterval: -200, since: now)
        )
        _ = UploadDataRecord.create(
            context: module.cache.coreData.context,
            id: "newest",
            type: EmbraceUploadType.spans.rawValue,
            data: Data("newest".utf8),
            payloadTypes: nil,
            date: Date(timeInterval: -100, since: now)
        )
        module.cache.coreData.save()

        module.retryCachedData()
        module.waitForAllWork()

        // All 3 records should be uploaded, oldest first
        let bodies = EmbraceHTTPMock.requestBodiesForUrl(spansUrl)
        XCTAssertEqual(bodies, ["oldest", "middle", "newest"].map { Data($0.utf8) })
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
        module.retryCachedData()

        // Immediately upload a new record
        var completed = false
        module.uploadSpans(id: "live-1", data: TestConstants.data) { _ in
            completed = true
        }

        module.waitForAllWork()
        XCTAssertTrue(completed)

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

        var completions = 0

        // Upload a span and a log simultaneously
        module.uploadSpans(id: "span-1", data: TestConstants.data) { _ in
            completions += 1
        }
        module.uploadLog(id: "log-1", data: TestConstants.data) { _ in
            completions += 1
        }

        module.waitForAllWork()
        XCTAssertEqual(completions, 2)

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
