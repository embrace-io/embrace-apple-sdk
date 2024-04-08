//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import TestSupport
@testable import EmbraceConfig

// swiftlint:disable force_try

class RemoteConfigFetcherTests: XCTestCase {
    static var urlSessionConfig: URLSessionConfiguration!

    func testOptions(testName: String = #function) -> EmbraceConfig.Options {
        return EmbraceConfig.Options(
            apiBaseUrl: "https://embrace.\(testName).com",
            queue: DispatchQueue(label: "com.test.embrace.queue", attributes: .concurrent),
            appId: TestConstants.appId,
            deviceId: TestConstants.deviceId,
            osVersion: TestConstants.osVersion,
            sdkVersion: TestConstants.sdkVersion,
            appVersion: TestConstants.appVersion,
            userAgent: TestConstants.userAgent,
            urlSessionConfiguration: RemoteConfigFetcherTests.urlSessionConfig
        )
    }

    override func setUpWithError() throws {
        // can't use ephemeral because we need to test the cache
        RemoteConfigFetcherTests.urlSessionConfig = URLSessionConfiguration.default
        RemoteConfigFetcherTests.urlSessionConfig.protocolClasses = [EmbraceHTTPMock.self]
    }

    func test_requestMetadata() {
        // given a fetcher
        let fetcher = RemoteConfigFetcher(options: testOptions())

        // then requests created are correct
        let request = fetcher.newRequest()

        let expectedUrl = "\(testOptions().apiBaseUrl)/v2/config?appId=\(testOptions().appId)&osVersion=\(testOptions().osVersion)&appVersion=\(testOptions().appVersion)&deviceId=\(testOptions().deviceId)&sdkVersion=\(testOptions().sdkVersion)"
        XCTAssertEqual(request!.url?.absoluteString, expectedUrl)
        XCTAssertEqual(request!.httpMethod, "GET")
        XCTAssertEqual(request!.allHTTPHeaderFields!["Accept"], "application/json")
        XCTAssertEqual(request!.allHTTPHeaderFields!["User-Agent"], "Embrace/i/\(testOptions().sdkVersion)")
    }

    func test_ETag() throws {
        // given a fetcher
        let fetcher = RemoteConfigFetcher(options: testOptions())

        // when there's a cached response
        let url = try XCTUnwrap(fetcher.buildURL())
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["ETag": "test"])!
        let firstRequest = fetcher.newRequest()!

        let cache = fetcher.session.configuration.urlCache!
        cache.storeCachedResponse(
            CachedURLResponse(response: response, data: Data()),
            for: firstRequest
        )

        // then the ETag is correctly handled in subsequent requests
        let secondRequest = fetcher.newRequest()!
        XCTAssertEqual(secondRequest.allHTTPHeaderFields!["If-None-Match"], "test")
    }

    func test_fetchSuccess() throws {
        // given a fetcher
        let fetcher = RemoteConfigFetcher(options: testOptions())

        // and a valid remote config
        let url = try XCTUnwrap(fetcher.buildURL())
        let path = Bundle.module.path(forResource: "remote_config", ofType: "json", inDirectory: "Mocks")!
        let data = try! Data(contentsOf: URL(fileURLWithPath: path))
        EmbraceHTTPMock.mock(url: url, data: data)

        // when fetching the config
        let expectation = XCTestExpectation()
        fetcher.fetch { payload in
            // then the payload is valid
            XCTAssertNotNil(payload)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)

        XCTAssertEqual(EmbraceHTTPMock.totalRequestCount(), 1)
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(url).count, 1)
    }

    func test_fetchSuccess_wrongResponseCode() throws {
        // given a fetcher
        let fetcher = RemoteConfigFetcher(options: testOptions())

        // and a valid remote config
        let url = try XCTUnwrap(fetcher.buildURL())
        let path = Bundle.module.path(forResource: "remote_config", ofType: "json", inDirectory: "Mocks")!
        let data = try! Data(contentsOf: URL(fileURLWithPath: path))

        // but an invalid response code
        EmbraceHTTPMock.mock(url: url, data: data, statusCode: 300)

        // when fetching the config
        let expectation = XCTestExpectation()
        fetcher.fetch { payload in
            // then the payload is not valid
            XCTAssertNil(payload)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)

        XCTAssertEqual(EmbraceHTTPMock.totalRequestCount(), 1)
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(url).count, 1)
    }

    func test_fetchFailure() throws {
        // given a fetcher
        let fetcher = RemoteConfigFetcher(options: testOptions())

        // when failing to fetch the config
        let url = try XCTUnwrap(fetcher.buildURL())
        EmbraceHTTPMock.mock(url: url, errorCode: 500)

        let expectation = XCTestExpectation()
        fetcher.fetch { payload in
            // then the payload is not valid
            XCTAssertNil(payload)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)

        XCTAssertEqual(EmbraceHTTPMock.totalRequestCount(), 1)
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(url).count, 1)
    }
}

// swiftlint:enable force_try
