//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import TestSupport
import XCTest

@testable import EmbraceCommonInternal
@testable import EmbraceCore

class DataTaskWithURLRequestSwizzlerTests: XCTestCase, @unchecked Sendable {
    private var session: URLSession!
    private var sut: DataTaskWithURLRequestSwizzler!
    private var handler: MockURLSessionTaskHandler!
    private var dataTask: URLSessionDataTask!

    override func tearDownWithError() throws {
        try? sut.unswizzleInstanceMethod()
    }

    func test_afterInstall_taskWillBeCreatedInHandler() async throws {
        givenDataTaskWithURLRequestSwizzler()
        try await givenSwizzlingWasDone()
        givenProxiedUrlSession()
        whenInvokingDataTaskWithUrl()
        thenHandlerShouldHaveInvokedCreateWithTask()
    }

    func test_afterInstall_taskShouldHaveEmbraceHeaders() async throws {
        givenDataTaskWithURLRequestSwizzler()
        try await givenSwizzlingWasDone()
        givenProxiedUrlSession()
        whenInvokingDataTaskWithUrl()
        try thenDataTaskShouldHaveEmbraceHeaders()
    }

    func test_withoutInstall_taskWontBeCreatedInHandler() throws {
        givenDataTaskWithURLRequestSwizzler()
        givenProxiedUrlSession()
        whenInvokingDataTaskWithUrl()
        thenHandlerShouldntHaveInvokedCreate()
    }
}

extension DataTaskWithURLRequestSwizzlerTests {
    fileprivate func givenDataTaskWithURLRequestSwizzler() {
        handler = MockURLSessionTaskHandler()
        sut = DataTaskWithURLRequestSwizzler(handler: handler)
    }

    fileprivate func givenSwizzlingWasDone() async throws {
        try await sut.install()
    }

    fileprivate func givenProxiedUrlSession() {
        session = ProxiedURLSessionProvider.default()
    }

    fileprivate func whenInvokingDataTaskWithUrl() {
        var url = URL(string: "https://embrace.io")!
        let request = URLRequest(url: url)
        let mockData = "Mock Data".data(using: .utf8)!
        let mockResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        url.mockResponse = .successful(withData: mockData, response: mockResponse)
        dataTask = session.dataTask(with: request)
        dataTask.resume()
    }

    fileprivate func thenHandlerShouldHaveInvokedCreateWithTask() {
        XCTAssertTrue(handler.didInvokeCreate)
        XCTAssertEqual(handler.createReceivedTask, dataTask)
    }

    fileprivate func thenHandlerShouldntHaveInvokedCreate() {
        XCTAssertFalse(handler.didInvokeCreate)
    }

    fileprivate func thenDataTaskShouldHaveEmbraceHeaders() throws {
        let headers = try XCTUnwrap(dataTask.originalRequest?.allHTTPHeaderFields)
        XCTAssertNotNil(headers["x-emb-id"])
        XCTAssertNotNil(headers["x-emb-st"])
    }
}
