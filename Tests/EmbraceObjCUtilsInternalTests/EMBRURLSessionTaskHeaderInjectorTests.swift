//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import TestSupport
@testable @_implementationOnly import EmbraceObjCUtilsInternal

final class EMBRURLSessionTaskHeaderInjectorTests: XCTestCase {
    private var task: URLSessionTask!

    func test_onInjectingHeader_shouldAppearOnOriginalAndCurrentRequest() throws {
        try givenURLSessionTask()
        whenInjectingHeader(key: "hello", value: "world")
        try thenOriginalRequestHasHeader(withKey: "hello", andValue: "world")
        try thenCurrentRequestHasHeader(withKey: "hello", andValue: "world")
    }

    func testStreamingTask_onInjectingHeader_shouldAppearOnlyOnCurrentRequest() throws {
        let urlSessionConfig = URLSessionConfiguration.ephemeral
        urlSessionConfig.httpMaximumConnectionsPerHost = .max
        urlSessionConfig.protocolClasses = [EmbraceHTTPMock.self]

        task = URLSession(configuration: urlSessionConfig).streamTask(withHostName: "https://embrace.io", port: 123)
        whenInjectingHeader(key: "hello", value: "world")
        try thenCurrentOriginalRequestHasNoHeader(withKey: "hello")
        try thenCurrentRequestHasHeader(withKey: "hello", andValue: "world")
    }
}

extension EMBRURLSessionTaskHeaderInjectorTests {
    func givenURLSessionTask() throws {
        let urlSessionconfig = URLSessionConfiguration.ephemeral
        urlSessionconfig.httpMaximumConnectionsPerHost = .max
        urlSessionconfig.protocolClasses = [EmbraceHTTPMock.self]
        task = URLSession(configuration: urlSessionconfig)
            .dataTask(with:
                        URLRequest(
                            url: URL(
                                string: "https://embrace.io/"
                            )!
                        )
            )
    }

    func whenInjectingHeader(key: String, value: String) {
        EMBRURLSessionTaskHeaderInjector.injectHeader(
            withKey: key,
            value: value,
            into: task
        )
    }

    func thenOriginalRequestHasHeader(withKey key: String, andValue value: String) throws {
        let headers = try XCTUnwrap(task.originalRequest?.allHTTPHeaderFields)
        XCTAssertTrue(headers.keys.contains(where: { $0 == key }))
        XCTAssertEqual(headers[key], value)
    }

    func thenCurrentRequestHasHeader(withKey key: String, andValue value: String) throws {
        let headers = try XCTUnwrap(task.currentRequest?.allHTTPHeaderFields)
        XCTAssertTrue(headers.keys.contains(where: { $0 == key }))
        XCTAssertEqual(headers[key], value)
    }

    func thenCurrentOriginalRequestHasNoHeader(withKey key: String) throws {
        XCTAssertNil(task.originalRequest?.allHTTPHeaderFields)
    }
}
