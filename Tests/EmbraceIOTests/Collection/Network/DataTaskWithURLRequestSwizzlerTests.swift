//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import TestSupport
@testable import EmbraceIO
@testable import EmbraceCommon

class DataTaskWithURLRequestSwizzlerTests: XCTestCase {
    private var session: URLSession!
    private var dataTaskSwizzler: DataTaskWithURLRequestSwizzler!
    private var handler: MockURLSessionTaskHandler!
    private var dataTask: URLSessionDataTask!

    override func tearDownWithError() throws {
        try? dataTaskSwizzler.unswizzleInstanceMethod()
    }

    func test_afterInstall_taskWillBeCreatedInHandler() throws {
        givenDataTaskWithURLRequestSwizzler()
        try givenSwizzledWasDone()
        givenProxiedUrlSession()
        whenInvokingDataTaskWithUrl()
        thenHandlerShouldHaveInvokedCreateWithTask()
    }

    func test_afterInstall_taskShouldHaveEmbraceHeaders() throws {
        givenDataTaskWithURLRequestSwizzler()
        try givenSwizzledWasDone()
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
        dataTaskSwizzler = DataTaskWithURLRequestSwizzler(handler: handler)
    }

    func givenSwizzledWasDone() throws {
        try dataTaskSwizzler.install()
    }

    func givenProxiedUrlSession() {
        session = ProxiedURLSessionProvider.default()
    }

    func whenInvokingDataTaskWithUrl() {
        let url = URL(string: "https://example.com")!
        var request = URLRequest(url: url)
        let mockData = "Mock Data".data(using: .utf8)
        let mockResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        request.mockResponse = .init(data: mockData, response: mockResponse)
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
