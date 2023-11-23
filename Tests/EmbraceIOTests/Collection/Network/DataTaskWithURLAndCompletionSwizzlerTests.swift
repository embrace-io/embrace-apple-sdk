//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import TestSupport
@testable import EmbraceIO
@testable import EmbraceCommon

class DataTaskWithURLAndCompletionSwizzlerTests: XCTestCase {
    private var session: URLSession!
    private var sut: DataTaskWithURLAndCompletionSwizzler!
    private var handler: MockURLSessionTaskHandler!
    private var url: URL!

    // To-Assert variables
    private var dataTask: URLSessionDataTask!
    private var resultData: Data!
    private var resultResponse: URLResponse!
    private var resultError: Error!

    override func tearDownWithError() throws {
        try? sut.unswizzleInstanceMethod()
    }

    func testAfterInstall_onExecutingRequest_taskWillBeCreatedInHandler() throws {
        let expectation = expectation(description: #function)
        givenDataTaskWithURLAndCompletionSwizzler()
        try givenSwizzledWasDone()
        givenSuccessfulRequest()
        givenProxiedUrlSession()
        whenInvokingDataTaskWithUrl(completionHandler: { _, _, _ in
            self.thenHandlerShouldHaveInvokedCreateWithTask()
            expectation.fulfill()
        })
        wait(for: [expectation])
    }

    func testAfterInstall_onFinishingRequest_taskWillBeFinishedInHandler() throws {
        let expectation = expectation(description: #function)
        givenDataTaskWithURLAndCompletionSwizzler()
        try givenSwizzledWasDone()
        givenSuccessfulRequest()
        givenProxiedUrlSession()
        whenInvokingDataTaskWithUrl(completionHandler: { _, _, _ in
            self.thenHandlerShouldHaveInvokedFinishTask()
            expectation.fulfill()
        })
        wait(for: [expectation])
    }

    func testAfterInstall_onFailedRequest_taskWillBeFinishedInHandler() throws {
        let expectation = expectation(description: #function)
        givenDataTaskWithURLAndCompletionSwizzler()
        try givenSwizzledWasDone()
        givenFailedRequest()
        givenProxiedUrlSession()
        whenInvokingDataTaskWithUrl(completionHandler: { _, _, _ in
            self.thenHandlerShouldHaveInvokedFinishTaskWithError()
            expectation.fulfill()
        })
        wait(for: [expectation])
    }

    func test_afterInstall_taskShouldHaveEmbraceHeaders() throws {
        let expectation = expectation(description: #function)
        givenDataTaskWithURLAndCompletionSwizzler()
        try givenSwizzledWasDone()
        givenProxiedUrlSession()
        givenSuccessfulRequest()
        whenInvokingDataTaskWithUrl(completionHandler: { _, _, _ in
            // swiftlint:disable force_try
            self.thenDataTaskShouldntHaveHeaders()
            // swiftlint:enable force_try
            expectation.fulfill()
        })
        wait(for: [expectation])
    }

    func test_withoutInstall_taskWontBeCreatedInHandler() throws {
        let expectation = expectation(description: #function)
        givenDataTaskWithURLAndCompletionSwizzler()
        givenProxiedUrlSession()
        givenSuccessfulRequest()
        whenInvokingDataTaskWithUrl(completionHandler: { _, _, _ in
            self.thenHandlerShouldntHaveInvokedCreate()
            expectation.fulfill()
        })
        wait(for: [expectation])
    }
}

private extension DataTaskWithURLAndCompletionSwizzlerTests {
    func givenDataTaskWithURLAndCompletionSwizzler() {
        handler = MockURLSessionTaskHandler()
        sut = DataTaskWithURLAndCompletionSwizzler(handler: handler)
    }

    func givenSwizzledWasDone() throws {
        try sut.install()
    }

    func givenProxiedUrlSession() {
        session = ProxiedURLSessionProvider.default()
    }

    func givenSuccessfulRequest() {
        url = URL(string: "https://embrace.io")!
        let mockData = "Mock Data".data(using: .utf8)!
        let mockResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        url.mockResponse = .sucessful(withData: mockData, response: mockResponse)
    }

    func givenFailedRequest() {
        url = URL(string: "https://embrace.io")!
        let error = NSError(domain: UUID().uuidString, code: 0)
        let mockResponse = HTTPURLResponse(url: url, statusCode: 400, httpVersion: nil, headerFields: nil)!
        url.mockResponse = .failure(withError: error, response: mockResponse)
    }

    func whenInvokingDataTaskWithUrl(completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) {
        dataTask = session.dataTask(with: url) { data, response, error in
            completionHandler(data, response, error)
        }
        dataTask.resume()
    }

    func thenHandlerShouldHaveInvokedCreateWithTask() {
        XCTAssertTrue(handler.didInvokeCreate)
        XCTAssertEqual(handler.createReceivedTask, dataTask)
    }

    func thenHandlerShouldntHaveInvokedCreate() {
        XCTAssertFalse(handler.didInvokeCreate)
    }

    func thenHandlerShouldHaveInvokedFinishTask() {
        XCTAssertTrue(handler.didInvokeFinish)
        XCTAssertNotNil(handler.finishReceivedParameters?.1)
    }

    func thenHandlerShouldHaveInvokedFinishTaskWithError() {
        XCTAssertTrue(handler.didInvokeFinish)
        XCTAssertNotNil(handler.finishReceivedParameters?.2)
    }

    func thenDataTaskShouldntHaveHeaders() {
        XCTAssertNil(dataTask.originalRequest?.allHTTPHeaderFields)
    }
}
