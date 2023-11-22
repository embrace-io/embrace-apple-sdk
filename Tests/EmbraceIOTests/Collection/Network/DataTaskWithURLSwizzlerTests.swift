//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import TestSupport
@testable import EmbraceIO
@testable import EmbraceCommon

class DataTaskWithURLSwizzlerTests: XCTestCase {
    private var session: URLSession!
    private var dataTaskSwizzler: DataTaskWithURLSwizzler!
    private var handler: MockURLSessionTaskHandler!
    private var dataTask: URLSessionDataTask!

    override func tearDownWithError() throws {
        try? dataTaskSwizzler.unswizzleInstanceMethod()
    }

    func test_afterInstall_taskWillBeCreatedInHandler() throws {
        givenDataTaskWithURLSwizzler()
        try givenSwizzledWasDone()
        givenProxiedUrlSession()
        whenInvokingDataTaskWithUrl()
        thenHandlerShouldHaveInvokedCreateWithTask()
    }

    func test_withoutInstall_taskWontBeCreatedInHandler() throws {
        givenDataTaskWithURLSwizzler()
        givenProxiedUrlSession()
        whenInvokingDataTaskWithUrl()
        thenHandlerShouldntHaveInvokedCreate()
    }
}

private extension DataTaskWithURLSwizzlerTests {
    func givenDataTaskWithURLSwizzler() {
        handler = MockURLSessionTaskHandler()
        dataTaskSwizzler = DataTaskWithURLSwizzler(handler: handler)
    }

    func givenSwizzledWasDone() throws {
        try dataTaskSwizzler.install()
    }

    func givenProxiedUrlSession() {
        session = ProxiedURLSessionProvider.default()
    }

    func whenInvokingDataTaskWithUrl() {
        var url = URL(string: "https://example.com")!
        let mockData = "Mock Data".data(using: .utf8)
        let mockResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        url.mockResponse = .init(data: mockData, response: mockResponse)
        dataTask = session.dataTask(with: url)
        dataTask.resume()
    }

    func thenHandlerShouldHaveInvokedCreateWithTask() {
        XCTAssertTrue(handler.didInvokeCreate)
        XCTAssertEqual(handler.createReceivedTask, dataTask)
    }

    func thenHandlerShouldntHaveInvokedCreate() {
        XCTAssertFalse(handler.didInvokeCreate)
    }
}
