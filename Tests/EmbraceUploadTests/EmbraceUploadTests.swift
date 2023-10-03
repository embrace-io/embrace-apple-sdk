//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import TestSupport
import GRDB
@testable import EmbraceUpload

class EmbraceUploadTests: XCTestCase {

    static let testSessionsUrl = URL(string: "https://embrace.test.com/sessions")!
    static let testBlobsUrl = URL(string: "https://embrace.test.com/blobs")!

    static let testEndpointOptions = EmbraceUpload.EndpointOptions(
        sessionsURL: EmbraceUploadTests.testSessionsUrl,
        blobsURL: EmbraceUploadTests.testBlobsUrl
    )
    static let testCacheOptions = EmbraceUpload.CacheOptions(cacheBaseUrl: URL(fileURLWithPath: NSTemporaryDirectory()))!
    static let testMetadataOptions = EmbraceUpload.MetadataOptions(apiKey: "apiKey", userAgent: "userAgent", deviceId: "12345678")
    static let testRedundancyOptions = EmbraceUpload.RedundancyOptions(automaticRetryCount: 0)

    var testOptions: EmbraceUpload.Options!
    var queue: DispatchQueue!

    override func setUpWithError() throws {
        if FileManager.default.fileExists(atPath: EmbraceUploadTests.testCacheOptions.cacheFilePath) {
            try FileManager.default.removeItem(atPath: EmbraceUploadTests.testCacheOptions.cacheFilePath)
        }

        let urlSessionconfig = URLSessionConfiguration.ephemeral
        urlSessionconfig.protocolClasses = [EmbraceHTTPMock.self]

        testOptions = EmbraceUpload.Options(
            endpoints: EmbraceUploadTests.testEndpointOptions,
            cache: EmbraceUploadTests.testCacheOptions,
            metadata: EmbraceUploadTests.testMetadataOptions,
            redundancy: EmbraceUploadTests.testRedundancyOptions,
            urlSessionConfiguration: urlSessionconfig
        )

        EmbraceHTTPMock.setUp()

        self.queue = DispatchQueue(label: "com.test.embrace.queue", attributes: .concurrent)
    }

    override func tearDownWithError() throws {

    }

    func test_invalidId() throws {
        let module = try EmbraceUpload(options: testOptions, queue: queue)

        // given an invalid identifier
        let expectation = XCTestExpectation()

        module.uploadSession(id: "", data: Data()) { result in
            switch result {
            case .failure(let error as NSError):
                // then the upload should fail with the correct code
                XCTAssertEqual(error.code, EmbraceUploadErrorCode.invalidMetadata.rawValue)
                expectation.fulfill()
            default:
                XCTAssert(false, "Upload should've failed!")
            }
        }

        wait(for: [expectation], timeout: TestConstants.defaultTimeout)
    }

    func test_invalidData() throws {
        let module = try EmbraceUpload(options: testOptions, queue: queue)

        // given an invalid data
        let expectation = XCTestExpectation()

        module.uploadSession(id: "id", data: Data()) { result in
            switch result {
            case .failure(let error as NSError):
                // then the upload should fail with the correct code
                XCTAssertEqual(error.code, EmbraceUploadErrorCode.invalidData.rawValue)
                expectation.fulfill()
            default:
                XCTAssert(false, "Upload should've failed!")
            }
        }

        wait(for: [expectation], timeout: TestConstants.defaultTimeout)
    }

    func test_successCompletion() throws {
        EmbraceHTTPMock.mock(url: EmbraceUploadTests.testSessionsUrl)

        let module = try EmbraceUpload(options: testOptions, queue: queue)

        // given valid values
        let expectation = XCTestExpectation()
        module.uploadSession(id: "id", data: TestConstants.data) { result in
            switch result {
            case .success:
                // then the upload should succeed
                expectation.fulfill()
            default:
                XCTAssert(false, "Upload should've succeeded!")
            }
        }

        wait(for: [expectation], timeout: TestConstants.defaultTimeout)
    }

    func test_cacheFlowOnSuccess() throws {
        EmbraceHTTPMock.mock(url: EmbraceUploadTests.testSessionsUrl)

        let module = try EmbraceUpload(options: testOptions, queue: queue)

        // given valid values
        let expectation1 = XCTestExpectation(description: "1. Data should be cached")
        let expectation2 = XCTestExpectation(description: "2. Upload should succeed")
        let expectation3 = XCTestExpectation(description: "3. Cache should be removed")
        var dataCached = false

        // then the data should be cached
        let observation = ValueObservation.tracking(UploadDataRecord.fetchAll)
        let cancellable = observation.start(in: module.cache.dbQueue) { error in
            XCTAssert(false, error.localizedDescription)
        } onChange: { records in
            // and its data should be valid
            if let record = records.first {
                XCTAssertEqual(record.id, "id")
                XCTAssertEqual(record.type, EmbraceUploadType.session.rawValue)
                XCTAssertEqual(record.data, TestConstants.data)
                dataCached = true
                expectation1.fulfill()

            // and it should be removed at the end
            } else if dataCached {
                expectation3.fulfill()
            }
        }

        // when uploading data
        module.uploadSession(id: "id", data: TestConstants.data) { result in
            switch result {
            case .success:
                // then the upload should succeed
                expectation2.fulfill()
            default:
                XCTAssert(false, "Upload should've succeeded!")
            }
        }

        wait(for: [expectation1, expectation2, expectation3], timeout: TestConstants.veryLongTimeout, enforceOrder: true)

        // clean up
        cancellable.cancel()
    }

    func test_cacheFlowOnError() throws {
        let module = try EmbraceUpload(options: testOptions, queue: queue)

        // given valid values
        let expectation1 = XCTestExpectation(description: "1. Data should be cached")
        let expectation2 = XCTestExpectation(description: "2. Upload should fail")

        // then the data should be cached
        let observation = ValueObservation.tracking(UploadDataRecord.fetchAll)
        let cancellable = observation.start(in: module.cache.dbQueue) { error in
            XCTAssert(false, error.localizedDescription)
        } onChange: { records in
            // and its data should be valid
            if let record = records.first {
                XCTAssertEqual(record.id, "id")
                XCTAssertEqual(record.type, EmbraceUploadType.session.rawValue)
                XCTAssertEqual(record.data, TestConstants.data)
                expectation1.fulfill()
            }
        }

        // when uploading data
        module.uploadSession(id: "id", data: TestConstants.data) { result in
            switch result {
            case .failure(let error):
                // then the upload should fail
                XCTAssertNotNil(error)
                expectation2.fulfill()
            default:
                XCTAssert(false, "Upload should've failed!")
            }
        }

        wait(for: [expectation1, expectation2], timeout: TestConstants.veryLongTimeout, enforceOrder: true)

        // data should remain cached
        let record = try module.cache.fetchUploadData(id: "id", type: .session)
        XCTAssertNotNil(record)

        // clean up
        cancellable.cancel()
    }

    func test_retryCachedData() throws {
        let module = try EmbraceUpload(options: testOptions, queue: queue)

        // given cached data
        _ = try module.cache.saveUploadData(id: "id1", type: .session, data: TestConstants.data)
        _ = try module.cache.saveUploadData(id: "id2", type: .blob, data: TestConstants.data)

        // when retrying to upload all cached data
        module.retryCachedData()

        _ = XCTWaiter.wait(for: [XCTestExpectation()], timeout: TestConstants.defaultTimeout)

        // then requests are made
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(EmbraceUploadTests.testSessionsUrl).count, 1)
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(EmbraceUploadTests.testBlobsUrl).count, 1)
    }

    func test_retryCachedData_emptyCache() throws {
        // given an empty cache
        let module = try EmbraceUpload(options: testOptions, queue: queue)

        // when retrying to upload all cached data
        module.retryCachedData()

        _ = XCTWaiter.wait(for: [XCTestExpectation()], timeout: TestConstants.defaultTimeout)

        // then no requests are made
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(EmbraceUploadTests.testSessionsUrl).count, 0)
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(EmbraceUploadTests.testBlobsUrl).count, 0)
    }

    func test_sessionsEndpoint() throws {
        let module = try EmbraceUpload(options: testOptions, queue: queue)

        // when uploading session data
        module.uploadSession(id: "id", data: TestConstants.data, completion: nil)

        _ = XCTWaiter.wait(for: [XCTestExpectation()], timeout: TestConstants.defaultTimeout)

        // then a request to the right endpoint is made
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(EmbraceUploadTests.testSessionsUrl).count, 1)
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(EmbraceUploadTests.testBlobsUrl).count, 0)
    }

    func test_blobsEndpoint() throws {
        let module = try EmbraceUpload(options: testOptions, queue: queue)

        // when uploading blob data
        module.uploadBlob(id: "id", data: TestConstants.data, completion: nil)

        _ = XCTWaiter.wait(for: [XCTestExpectation()], timeout: TestConstants.defaultTimeout)

        // then a request to the right endpoint is made
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(EmbraceUploadTests.testSessionsUrl).count, 0)
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(EmbraceUploadTests.testBlobsUrl).count, 1)
    }
}
