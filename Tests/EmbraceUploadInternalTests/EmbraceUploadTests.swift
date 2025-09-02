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
    static let testRedundancyOptions = EmbraceUpload.RedundancyOptions(automaticRetryCount: 0)

    var testOptions: EmbraceUpload.Options!
    var queue: DispatchQueue!
    var module: EmbraceUpload!

    override func setUpWithError() throws {
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
        module.operationQueue.waitUntilAllOperationsAreFinished()
    }

    func test_invalidId() throws {
        // given an invalid identifier
        let expectation = XCTestExpectation()

        module.uploadSpans(id: "", data: Data()) { result in
            switch result {
            case .failure(let error as NSError):
                // then the upload should fail with the correct code
                XCTAssertEqual(error.code, EmbraceUploadErrorCode.invalidMetadata.rawValue)
                expectation.fulfill()
            default:
                XCTAssert(false, "Upload should've failed!")
            }
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_invalidData() throws {
        // given an invalid data
        let expectation = XCTestExpectation()

        module.uploadSpans(id: "id", data: Data()) { result in
            switch result {
            case .failure(let error as NSError):
                // then the upload should fail with the correct code
                XCTAssertEqual(error.code, EmbraceUploadErrorCode.invalidData.rawValue)
                expectation.fulfill()
            default:
                XCTAssert(false, "Upload should've failed!")
            }
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_success() throws {
        try XCTSkipIf(XCTestCase.isWatchOS())

        EmbraceHTTPMock.mock(url: testSpansUrl())

        // given valid values
        let expectation = XCTestExpectation()

        module.uploadSpans(id: "id", data: TestConstants.data) { result in
            switch result {
            case .success:
                // then the success completion callback is called without
                expectation.fulfill()
            default:
                XCTAssert(false, "Upload should've succeeded!")
            }
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_cacheFlowOnSuccess() throws {
        try XCTSkipIf(XCTestCase.isWatchOS())

        EmbraceHTTPMock.mock(url: testSpansUrl())

        // given valid values
        let expectation1 = XCTestExpectation(description: "1. Data should be cached in the database")
        let expectation2 = XCTestExpectation(description: "2. Success completion callback should be called")
        let expectation3 = XCTestExpectation(description: "3. Cache should be removed")
        var dataCached = false

        // then the data should be cached
        let listener = CoreDataListener()

        listener.onInsertedObjects = { objects in
            guard let record = objects.first as? UploadDataRecord else {
                return
            }

            XCTAssertEqual(record.id, "id")
            XCTAssertEqual(record.type, EmbraceUploadType.spans.rawValue)
            XCTAssertEqual(record.data, TestConstants.data)
            dataCached = true
            expectation1.fulfill()
        }

        listener.onDeletedObjects = { objects in
            if dataCached {
                expectation3.fulfill()
            }
        }

        // when uploading data
        module.uploadSpans(id: "id", data: TestConstants.data) { result in
            switch result {
            case .success:
                // then the cache step succeeds
                expectation2.fulfill()
            default:
                XCTAssert(false, "Upload should've succeeded!")
            }
        }

        // Note: we would like to enforce order for these but
        // the observability on the database seems to be inconsistent timing wise
        // so the first 2 steps are not always in the same order
        wait(for: [expectation1, expectation2, expectation3], timeout: .veryLongTimeout)
    }

    func test_cacheFlowOnError() throws {
        // given valid values
        let expectation1 = XCTestExpectation(description: "1. Data should be cached in the database")
        let expectation2 = XCTestExpectation(description: "2. Sucess completion callback should be called")

        // then the data should be cached
        let listener = CoreDataListener()

        listener.onInsertedObjects = { objects in
            guard let record = objects.first as? UploadDataRecord else {
                return
            }

            XCTAssertEqual(record.id, "id")
            XCTAssertEqual(record.type, EmbraceUploadType.spans.rawValue)
            XCTAssertEqual(record.data, TestConstants.data)
            expectation1.fulfill()
        }

        // when uploading data
        module.uploadSpans(id: "id", data: TestConstants.data) { result in
            switch result {
            case .success:
                // then the cache step succeeds
                expectation2.fulfill()
            default:
                XCTAssert(false, "Upload should've succeeded!")
            }
        }

        wait(for: [expectation1, expectation2], timeout: .veryLongTimeout)

        // the ndata should remain cached
        let record = module.cache.fetchUploadData(id: "id", type: .spans)
        XCTAssertNotNil(record)
    }

    func test_retryCachedData() async throws {
        try XCTSkipIf(XCTestCase.isWatchOS())

        // given cached data
        _ = module.cache.saveUploadData(id: "id1", type: .spans, data: TestConstants.data)
        _ = module.cache.saveUploadData(id: "id2", type: .log, data: TestConstants.data)

        EmbraceHTTPMock.mock(url: testSpansUrl())
        EmbraceHTTPMock.mock(url: testLogsUrl())

        // when retrying to upload all cached data
        await module.retryCachedData()

        // then requests are made
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(testSpansUrl()).count, 1)
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(testLogsUrl()).count, 1)
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(testAttachmentsUrl()).count, 0)
    }

    func test_retryCachedData_emptyCache() async throws {
        // given an empty cache

        // when retrying to upload all cached data
        await module.retryCachedData()

        // then no requests are made
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(testSpansUrl()).count, 0)
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(testLogsUrl()).count, 0)
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(testAttachmentsUrl()).count, 0)
    }

    func test_spansEndpoint() throws {
        try XCTSkipIf(XCTestCase.isWatchOS())

        // when uploading session data
        let expectation = XCTestExpectation()
        module.uploadSpans(id: "id", data: TestConstants.data) { _ in
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: .defaultTimeout)

        // then a request to the right endpoint is made
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(testSpansUrl()).count, 1)
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(testLogsUrl()).count, 0)
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(testAttachmentsUrl()).count, 0)
    }

    func test_logsEndpoint() throws {
        try XCTSkipIf(XCTestCase.isWatchOS())

        // when uploading log data
        let expectation = XCTestExpectation()
        module.uploadLog(id: "id", data: TestConstants.data) { _ in
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: .defaultTimeout)

        // then a request to the right endpoint is made
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(testSpansUrl()).count, 0)
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(testLogsUrl()).count, 1)
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(testAttachmentsUrl()).count, 0)
    }

    func test_attachmentsEndpoint() throws {
        try XCTSkipIf(XCTestCase.isWatchOS())

        // when uploading attachment data
        let expectation = XCTestExpectation()
        module.uploadAttachment(id: "id", data: TestConstants.data) { _ in
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)

        // then a request to the right endpoint is made
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(testSpansUrl()).count, 0)
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(testLogsUrl()).count, 0)
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(testAttachmentsUrl()).count, 1)
    }
}

extension EmbraceUploadTests {
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
