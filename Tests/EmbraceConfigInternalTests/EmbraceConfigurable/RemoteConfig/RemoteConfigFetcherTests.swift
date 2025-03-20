//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import TestSupport
@testable import EmbraceConfigInternal
import EmbraceCommonInternal

class RemoteConfigFetcherTests: XCTestCase {
    static var urlSessionConfig: URLSessionConfiguration!
    let logger = MockLogger()

    private var apiBaseUrl: String {
        "https://embrace.\(testName).com/config"
    }

    override func setUpWithError() throws {
        let config = URLSessionConfiguration.ephemeral
        config.httpMaximumConnectionsPerHost = .max
        Self.urlSessionConfig = config
        Self.urlSessionConfig.protocolClasses = [EmbraceHTTPMock.self]
    }

    func fetcherOptions(
        deviceId: DeviceIdentifier = TestConstants.deviceId,
        queue: DispatchQueue = DispatchQueue(label: "com.test.embrace.queue", attributes: .concurrent),
        appId: String = TestConstants.appId,
        osVersion: String = TestConstants.osVersion,
        sdkVersion: String = TestConstants.sdkVersion,
        appVersion: String = TestConstants.appVersion,
        userAgent: String = TestConstants.userAgent
    ) -> RemoteConfig.Options {
        return RemoteConfig.Options(
            apiBaseUrl: apiBaseUrl,
            queue: DispatchQueue(label: "com.test.embrace.queue", attributes: .concurrent),
            appId: appId,
            deviceId: deviceId,
            osVersion: osVersion,
            sdkVersion: sdkVersion,
            appVersion: appVersion,
            userAgent: userAgent,
            cacheLocation: nil,
            urlSessionConfiguration: Self.urlSessionConfig
        )
    }

    func mockSuccessfulResponse() throws {
        var url = try XCTUnwrap(URL(string: "\(apiBaseUrl)/v2/config"))

        if #available(iOS 16.0, watchOS 9.0, tvOS 16.0, *) {
            url.append(queryItems: [
                .init(name: "appId", value: TestConstants.appId),
                .init(name: "osVersion", value: TestConstants.osVersion),
                .init(name: "appVersion", value: TestConstants.appVersion),
                .init(name: "sdkVersion", value: TestConstants.sdkVersion)
            ])
        } else {
            XCTFail("This will fail on versions prior to iOS 16.0")
        }

        let path = Bundle.module.path(
            forResource: "remote_config",
            ofType: "json",
            inDirectory: "Fixtures"
        )!
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        EmbraceHTTPMock.mock(url: url, response: .withData(data, statusCode: 200))
    }

    func mock404Response() throws {
        var url = try XCTUnwrap(URL(string: "\(apiBaseUrl)/v2/config"))

        if #available(iOS 16.0, watchOS 9.0, tvOS 16.0, *) {
            url.append(queryItems: [
                .init(name: "appId", value: TestConstants.appId),
                .init(name: "osVersion", value: TestConstants.osVersion),
                .init(name: "appVersion", value: TestConstants.appVersion),
                .init(name: "deviceId", value: TestConstants.deviceId.hex),
                .init(name: "sdkVersion", value: TestConstants.sdkVersion)
            ])
        } else {
            XCTFail("This will fail on versions prior to iOS 16.0")
        }

        EmbraceHTTPMock.mock(url: url, response: .withData(Data(), statusCode: 404))
    }

    // MARK: buildURL
    func test_buildURL_addsCorrectQuery() throws {
        let fetcher = RemoteConfigFetcher(options: fetcherOptions(), logger: logger)
        let url = try XCTUnwrap(fetcher.buildURL())
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)

        let queryItems = try XCTUnwrap(components?.queryItems)
        XCTAssertTrue(queryItems.contains { $0.name == "appId" && $0.value == TestConstants.appId })
        XCTAssertTrue(queryItems.contains { $0.name == "osVersion" && $0.value == TestConstants.osVersion })
        XCTAssertTrue(queryItems.contains { $0.name == "appVersion" && $0.value == TestConstants.appVersion })
        XCTAssertTrue(queryItems.contains { $0.name == "sdkVersion" && $0.value == TestConstants.sdkVersion })
        XCTAssertEqual(queryItems.count, 4)
    }

    // MARK: newRequest
    func test_newRequest_hasCorrectHeaders() throws {
        let fetcher = RemoteConfigFetcher(options: fetcherOptions(), logger: logger)
        let request = try XCTUnwrap(fetcher.newRequest())

        XCTAssertEqual(request.cachePolicy, .useProtocolCachePolicy)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "User-Agent"), TestConstants.userAgent)
    }

    func test_newRequest_addsETagWhenCachedResponsePresent() throws {
        let fetcher = RemoteConfigFetcher(options: fetcherOptions(), logger: logger)
        let response = HTTPURLResponse(
            url: try XCTUnwrap(fetcher.buildURL()),
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["ETag": "stubbed-etag"]
        )!
        let firstRequest = fetcher.newRequest()!
        XCTAssertNil(firstRequest.value(forHTTPHeaderField: "ETag"))

        let cache = try XCTUnwrap(Self.urlSessionConfig.urlCache)
        cache.storeCachedResponse(
            CachedURLResponse(response: response, data: Data()),
            for: firstRequest
        )

        let request = try XCTUnwrap(fetcher.newRequest())
        XCTAssertEqual(request.value(forHTTPHeaderField: "If-None-Match"), "stubbed-etag")
    }

    // MARK: fetch
    func test_fetch_completesSuccessfullyWithPayload() throws {
        // given a config with 1 hour minimum update interval
        let options = fetcherOptions()

        // Given the response is successful
        try mockSuccessfulResponse()

        // Given an RemoteConfig (executes fetch on init)
        let fetcher = RemoteConfigFetcher(options: options, logger: logger)

        let expectation = expectation(description: "URL request")
        fetcher.fetch { payload, data in
            XCTAssertNotNil(payload)
            expectation.fulfill()
        }
        wait(for: [expectation])
    }

    func test_fetch_completesFailureWithNilPayload() throws {
        // given a config with 1 hour minimum update interval
        let options = fetcherOptions()

        // Given the response is successful
        try mock404Response()

        // Given an RemoteConfig (executes fetch on init)
        let fetcher = RemoteConfigFetcher(options: options, logger: logger)

        let expectation = expectation(description: "URL request")
        fetcher.fetch { payload, data in
            XCTAssertNil(payload)
            expectation.fulfill()
        }
        wait(for: [expectation])
    }
}
