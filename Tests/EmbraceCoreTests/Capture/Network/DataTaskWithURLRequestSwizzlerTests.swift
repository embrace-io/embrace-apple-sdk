//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import TestSupport
@testable import EmbraceCore
@testable import EmbraceCommonInternal

class DataTaskWithURLRequestSwizzlerTests: XCTestCase {
    private var session: URLSession!
    private var sut: DataTaskWithURLRequestSwizzler!
    private var handler: MockURLSessionTaskHandler!
    private var dataTask: URLSessionDataTask!

    override func tearDownWithError() throws {
        try? sut.unswizzleInstanceMethod()
    }

    func test_afterInstall_taskWillBeCreatedInHandler() throws {
        givenDataTaskWithURLRequestSwizzler()
        try givenSwizzlingWasDone()
        givenProxiedUrlSession()
        whenInvokingDataTaskWithUrl()
        thenHandlerShouldHaveInvokedCreateWithTask()
    }

    func test_afterInstall_taskShouldHaveEmbraceHeaders() throws {
        givenDataTaskWithURLRequestSwizzler()
        try givenSwizzlingWasDone()
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

private extension DataTaskWithURLRequestSwizzlerTests {
    func givenDataTaskWithURLRequestSwizzler() {
        handler = MockURLSessionTaskHandler()
        sut = DataTaskWithURLRequestSwizzler(handler: handler)
    }

    func givenSwizzlingWasDone() throws {
        try sut.install()
    }

    func givenProxiedUrlSession() {
        session = ProxiedURLSessionProvider.default()
    }

    func whenInvokingDataTaskWithUrl() {
        var url = URL(string: "https://embrace.io")!
        let request = URLRequest(url: url)
        let mockData = "Mock Data".data(using: .utf8)!
        let mockResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        url.mockResponse = .successful(withData: mockData, response: mockResponse)
        dataTask = session.dataTask(with: request)
        dataTask.resume()
    }

    func thenHandlerShouldHaveInvokedCreateWithTask() {
        XCTAssertTrue(handler.didInvokeCreate)
        XCTAssertEqual(handler.createReceivedTask, dataTask)
    }

    func thenHandlerShouldntHaveInvokedCreate() {
        XCTAssertFalse(handler.didInvokeCreate)
    }

    func thenDataTaskShouldHaveEmbraceHeaders() throws {
        let headers = try XCTUnwrap(dataTask.originalRequest?.allHTTPHeaderFields)
        XCTAssertNotNil(headers["x-emb-id"])
        XCTAssertNotNil(headers["x-emb-st"])
    }
}
