//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import TestSupport
import XCTest

@testable import EmbraceUploadInternal

class EmbraceUploadTests: XCTestCase {
    static let testMetadataOptions = EmbraceUpload.MetadataOptions(
        apiKey: "apiKey",
        userAgent: "userAgent",
        deviceId: "12345678"
    )
    static let testRedundancyOptions = EmbraceUpload.RedundancyOptions(
        automaticRetryCount: 0,
        retryOnInternetConnected: false
    )

    var testOptions: EmbraceUpload.Options!
    var queue: DispatchQueue!
    var module: EmbraceUpload!

    override func setUpWithError() throws {
        // EmbraceHTTPMock state is process-wide; reset between methods.
        EmbraceHTTPMock.clearRequests()

        let urlSessionconfig = URLSessionConfiguration.ephemeral
        urlSessionconfig.httpMaximumConnectionsPerHost = .max
        urlSessionconfig.protocolClasses = [EmbraceHTTPMock.self]

        testOptions = EmbraceUpload.Options(
            endpoints: testEndpointOptions(testName: testName),
            cache: EmbraceUpload.CacheOptions(
                storageMechanism: .inMemory(name: testName), enableBackgroundTasks: false),
            metadata: EmbraceUploadTests.testMetadataOptions,
            redundancy: EmbraceUploadTests.testRedundancyOptions,
            urlSessionConfiguration: urlSessionconfig
        )

        self.queue = DispatchQueue(label: "com.test.embrace.queue")
        module = try EmbraceUpload(
            options: testOptions, logger: MockLogger(), queue: queue)
    }

    override func tearDownWithError() throws {
        // prevents inconsistent errors due to the cache database being forcefully deleted on each test
        module.waitForAllWork()
    }

    func test_invalidId() throws {
        // given an invalid identifier
        var result: Result<(), Error>?
        module.uploadSpans(id: "", data: Data()) { result = $0 }

        // the completion runs on the coordination queue
        queue.sync {}

        // then the upload should fail with the correct code
        guard case .failure(let error as NSError) = result else {
            return XCTFail("Upload should've failed!")
        }
        XCTAssertEqual(error.code, EmbraceUploadErrorCode.invalidMetadata.rawValue)
    }

    func test_invalidData() throws {
        // given an invalid data
        var result: Result<(), Error>?
        module.uploadSpans(id: "id", data: Data()) { result = $0 }

        // the completion runs on the coordination queue
        queue.sync {}

        // then the upload should fail with the correct code
        guard case .failure(let error as NSError) = result else {
            return XCTFail("Upload should've failed!")
        }
        XCTAssertEqual(error.code, EmbraceUploadErrorCode.invalidData.rawValue)
    }

    func test_success() throws {
        try XCTSkipIf(XCTestCase.isWatchOS())

        EmbraceHTTPMock.mock(url: testSpansUrl())

        // given valid values
        var result: Result<(), Error>?
        module.uploadSpans(id: "id", data: TestConstants.data) { result = $0 }

        // the completion runs on the coordination queue
        queue.sync {}

        // then the success completion callback is called
        guard case .success = result else {
            return XCTFail("Upload should've succeeded!")
        }
    }

    func test_cacheFlowOnSuccess() throws {
        try XCTSkipIf(XCTestCase.isWatchOS())

        EmbraceHTTPMock.mock(url: testSpansUrl())

        // when uploading data
        var completed = false
        module.uploadSpans(id: "id", data: TestConstants.data) { result in
            guard case .success = result else {
                return XCTFail("Upload should've succeeded!")
            }

            // then the data is cached before the completion fires
            self.assertCachedRecord(id: "id")
            completed = true
        }

        module.waitForAllWork()
        XCTAssertTrue(completed)

        // then the cache is removed after the upload succeeds
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(testSpansUrl()).count, 1)
        XCTAssertNil(module.cache.fetchUploadData(id: "id", type: .spans))
    }

    func test_cacheFlowOnError() throws {
        // given valid values (no mock URL, so upload will fail)

        // when uploading data
        // completion fires immediately after cache write (cache-first semantics)
        var completed = false
        module.uploadSpans(id: "id", data: TestConstants.data) { result in
            guard case .success = result else {
                return XCTFail("Upload should've succeeded!")
            }

            // then the data is cached before the completion fires
            self.assertCachedRecord(id: "id")
            completed = true
        }

        module.waitForAllWork()
        XCTAssertTrue(completed)

        // With retryCount: 0, the failed upload operation deletes the record from cache
        XCTAssertNil(module.cache.fetchUploadData(id: "id", type: .spans))
    }

    func test_retryCachedData() throws {
        try XCTSkipIf(XCTestCase.isWatchOS())

        // given cached data
        _ = module.cache.saveUploadData(id: "id1", type: .spans, data: TestConstants.data)
        _ = module.cache.saveUploadData(id: "id2", type: .log, data: TestConstants.data)

        EmbraceHTTPMock.mock(url: testSpansUrl())
        EmbraceHTTPMock.mock(url: testLogsUrl())

        // when retrying to upload all cached data
        module.retryCachedData()
        module.waitForAllWork()

        // then requests are made
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(testSpansUrl()).count, 1)
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(testLogsUrl()).count, 1)
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(testAttachmentsUrl()).count, 0)
    }

    func test_retryCachedData_emptyCache() throws {
        // given an empty cache

        // when retrying to upload all cached data
        module.retryCachedData()

        // an operation created by mistake would be waited on here, so its request is counted below
        module.waitForAllWork()

        // then no requests are made
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(testSpansUrl()).count, 0)
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(testLogsUrl()).count, 0)
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(testAttachmentsUrl()).count, 0)
    }

    func test_spansEndpoint() throws {
        try XCTSkipIf(XCTestCase.isWatchOS())

        EmbraceHTTPMock.mock(url: testSpansUrl())

        // when uploading session data
        var completed = false
        module.uploadSpans(id: "id", data: TestConstants.data) { _ in
            completed = true
        }

        module.waitForAllWork()
        XCTAssertTrue(completed)

        // then a request to the right endpoint is made
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(testSpansUrl()).count, 1)
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(testLogsUrl()).count, 0)
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(testAttachmentsUrl()).count, 0)
    }

    func test_logsEndpoint() throws {
        try XCTSkipIf(XCTestCase.isWatchOS())

        EmbraceHTTPMock.mock(url: testLogsUrl())

        // when uploading log data
        var completed = false
        module.uploadLog(id: "id", data: TestConstants.data) { _ in
            completed = true
        }

        module.waitForAllWork()
        XCTAssertTrue(completed)

        // then a request to the right endpoint is made
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(testSpansUrl()).count, 0)
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(testLogsUrl()).count, 1)
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(testAttachmentsUrl()).count, 0)
    }

    func test_attachmentsEndpoint() throws {
        try XCTSkipIf(XCTestCase.isWatchOS())

        EmbraceHTTPMock.mock(url: testAttachmentsUrl())

        // when uploading attachment data
        var completed = false
        module.uploadAttachment(id: "id", data: TestConstants.data) { _ in
            completed = true
        }

        module.waitForAllWork()
        XCTAssertTrue(completed)

        // then a request to the right endpoint is made
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(testSpansUrl()).count, 0)
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(testLogsUrl()).count, 0)
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(testAttachmentsUrl()).count, 1)
    }
}

extension EmbraceUploadTests {
    fileprivate func assertCachedRecord(id: String, file: StaticString = #filePath, line: UInt = #line) {
        let request = module.cache.fetchUploadDataRequest(id: id, type: .spans)
        module.cache.coreData.fetchAndPerform(withRequest: request) { records, _ in
            guard let record = records.first else {
                return XCTFail("Data should be cached in the database", file: file, line: line)
            }
            XCTAssertEqual(record.data, TestConstants.data, file: file, line: line)
        }
    }

    fileprivate func testSpansUrl(testName: String = #function) -> URL {
        URL(string: "https://embrace.\(testName).com/upload/sessions")!
    }

    fileprivate func testLogsUrl(testName: String = #function) -> URL {
        URL(string: "https://embrace.\(testName).com/upload/logs")!
    }

    fileprivate func testAttachmentsUrl(testName: String = #function) -> URL {
        URL(string: "https://embrace.\(testName).com/upload/attachments")!
    }

    fileprivate func testEndpointOptions(testName: String) -> EmbraceUpload.EndpointOptions {
        .init(
            spansURL: testSpansUrl(testName: testName),
            logsURL: testLogsUrl(testName: testName),
            attachmentsURL: testAttachmentsUrl(testName: testName)
        )
    }
}
