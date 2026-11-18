//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceSemantics
import TestSupport
import XCTest

@testable import EmbraceConfigInternal

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
        deviceId: EmbraceIdentifier = TestConstants.deviceId,
        queue: DispatchQueue = DispatchQueue(label: "com.test.embrace.queue"),
        appId: String = TestConstants.appId,
        osVersion: String = TestConstants.osVersion,
        sdkVersion: String = TestConstants.sdkVersion,
        appVersion: String = TestConstants.appVersion,
        userAgent: String = TestConstants.userAgent
    ) -> RemoteConfig.Options {
        return RemoteConfig.Options(
            apiBaseUrl: apiBaseUrl,
            queue: DispatchQueue(label: "com.test.embrace.queue"),
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

        if #available(iOS 16.0, tvOS 16.0, *) {
            url.append(queryItems: [
                .init(name: "appId", value: TestConstants.appId),
                .init(name: "osVersion", value: TestConstants.osVersion),
                .init(name: "appVersion", value: TestConstants.appVersion),
                .init(name: "sdkVersion", value: TestConstants.sdkVersion)
            ])
        } else {
            XCTFail("This will fail on versions prior to iOS 16.0")
        }

        EmbraceHTTPMock.mock(url: url, response: .withData(try remoteConfigFixture(), statusCode: 200))
    }

    func remoteConfigFixture() throws -> Data {
        let path = try XCTUnwrap(Bundle.module.path(forResource: "remote_config", ofType: "json", inDirectory: "Fixtures"))
        return try Data(contentsOf: URL(fileURLWithPath: path))
    }

    func httpResponse(statusCode: Int) throws -> HTTPURLResponse {
        try XCTUnwrap(
            HTTPURLResponse(
                url: try XCTUnwrap(URL(string: apiBaseUrl)), statusCode: statusCode, httpVersion: nil, headerFields: nil
            ))
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
        // given a successful response
        try mockSuccessfulResponse()
        let fetcher = RemoteConfigFetcher(options: fetcherOptions(), logger: logger)

        // when fetching
        let expectation = expectation(description: "URL request")
        var fetchedPayload: RemoteConfigPayload?
        var fetchedData: Data?
        fetcher.fetch { payload, data in
            fetchedPayload = payload
            fetchedData = data
            expectation.fulfill()
        }

        // then the request goes through the session and the response is decoded
        // (a positive wait: it returns as soon as the response arrives)
        wait(for: [expectation], timeout: 30)
        XCTAssertNotNil(fetchedPayload)
        XCTAssertEqual(fetchedData, try remoteConfigFixture())
    }

    // MARK: result
    func test_result_successfulResponse_returnsPayloadAndData() throws {
        let data = try remoteConfigFixture()

        let result = RemoteConfigFetcher.result(
            data: data, response: try httpResponse(statusCode: 200), error: nil, logger: logger)

        XCTAssertEqual(result.payload, try JSONDecoder().decode(RemoteConfigPayload.self, from: data))
        XCTAssertEqual(result.data, data)
    }

    func test_result_unsuccessfulStatusCode_returnsNil() throws {
        let result = RemoteConfigFetcher.result(
            data: Data(), response: try httpResponse(statusCode: 404), error: nil, logger: logger)

        XCTAssertNil(result.payload)
        XCTAssertNil(result.data)
    }

    func test_result_requestError_returnsNil() throws {
        let result = RemoteConfigFetcher.result(
            data: nil, response: nil, error: NSError(domain: TestConstants.domain, code: 500), logger: logger)

        XCTAssertNil(result.payload)
        XCTAssertNil(result.data)
    }

    func test_result_responseThatIsNotHTTP_returnsNil() throws {
        let response = URLResponse(
            url: try XCTUnwrap(URL(string: apiBaseUrl)), mimeType: nil, expectedContentLength: 0, textEncodingName: nil)

        let result = RemoteConfigFetcher.result(
            data: try remoteConfigFixture(), response: response, error: nil, logger: logger)

        XCTAssertNil(result.payload)
        XCTAssertNil(result.data)
    }

    func test_result_bodyThatDoesNotDecode_returnsDefaultPayload() throws {
        let result = RemoteConfigFetcher.result(
            data: Data("not json".utf8), response: try httpResponse(statusCode: 200), error: nil, logger: logger)

        XCTAssertEqual(result.payload, RemoteConfigPayload())
        XCTAssertNil(result.data)
    }
}
