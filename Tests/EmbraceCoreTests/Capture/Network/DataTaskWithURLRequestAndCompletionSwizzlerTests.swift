//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import TestSupport
import XCTest

@testable import EmbraceCommonInternal
@testable import EmbraceCore

class DataTaskWithURLRequestAndCompletionSwizzlerTests: XCTestCase {
    private var session: URLSession!
    private var sut: DataTaskWithURLRequestAndCompletionSwizzler!
    private var handler: MockURLSessionTaskHandler!
    private var request: URLRequest!

    private var dataTask: URLSessionDataTask!

    override func tearDownWithError() throws {
        try? sut.unswizzleInstanceMethod()
    }

    func testAfterInstall_onExecutingRequest_taskWillBeCreatedInHandler() throws {
        let expectation = expectation(description: #function)
        givenDataTaskWithURLRequestSwizzler()
        try givenSwizzlingWasDone()
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
        givenDataTaskWithURLRequestSwizzler()
        try givenSwizzlingWasDone()
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
        givenDataTaskWithURLRequestSwizzler()
        try givenSwizzlingWasDone()
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
        givenDataTaskWithURLRequestSwizzler()
        try givenSwizzlingWasDone()
        givenProxiedUrlSession()
        givenSuccessfulRequest()
        whenInvokingDataTaskWithUrl(completionHandler: { _, _, _ in
            // swiftlint:disable force_try
            try! self.thenDataTaskShouldHaveEmbraceHeaders()
            // swiftlint:enable force_try
            expectation.fulfill()
        })
        wait(for: [expectation])
    }

    func test_withoutInstall_taskWontBeCreatedInHandler() throws {
        let expectation = expectation(description: #function)
        givenDataTaskWithURLRequestSwizzler()
        givenProxiedUrlSession()
        givenSuccessfulRequest()
        whenInvokingDataTaskWithUrl(completionHandler: { _, _, _ in
            self.thenHandlerShouldntHaveInvokedCreate()
            expectation.fulfill()
        })
        wait(for: [expectation])
    }
}

extension DataTaskWithURLRequestAndCompletionSwizzlerTests {
    fileprivate func givenDataTaskWithURLRequestSwizzler() {
        handler = MockURLSessionTaskHandler()
        sut = DataTaskWithURLRequestAndCompletionSwizzler(handler: handler)
    }

    fileprivate func givenSwizzlingWasDone() throws {
        try sut.install()
    }

    fileprivate func givenProxiedUrlSession() {
        session = ProxiedURLSessionProvider.default()
    }

    fileprivate func givenSuccessfulRequest() {
        var url = URL(string: "https://embrace.io")!
        request = URLRequest(url: url)
        let mockData = "Mock Data".data(using: .utf8)!
        let mockResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        url.mockResponse = .successful(withData: mockData, response: mockResponse)
    }

    fileprivate func givenFailedRequest() {
        var url = URL(string: "https://embrace.io")!
        request = URLRequest(url: url)
        let error = NSError(domain: UUID().uuidString, code: 0)
        let mockResponse = HTTPURLResponse(url: url, statusCode: 400, httpVersion: nil, headerFields: nil)!
        url.mockResponse = .failure(withError: error, response: mockResponse)
    }

    fileprivate func whenInvokingDataTaskWithUrl(completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) {
        dataTask = session.dataTask(with: request) { data, response, error in
            completionHandler(data, response, error)
        }
        dataTask.resume()
    }

    fileprivate func thenHandlerShouldHaveInvokedCreateWithTask() {
        XCTAssertTrue(handler.didInvokeCreate)
        XCTAssertEqual(handler.createReceivedTask, dataTask)
    }

    fileprivate func thenHandlerShouldntHaveInvokedCreate() {
        XCTAssertFalse(handler.didInvokeCreate)
    }

    fileprivate func thenHandlerShouldHaveInvokedFinishTask() {
        XCTAssertTrue(handler.didInvokeFinishWithData)
        XCTAssertNotNil(handler.finishWithDataReceivedParameters?.1)
    }

    fileprivate func thenHandlerShouldHaveInvokedFinishTaskWithError() {
        XCTAssertTrue(handler.didInvokeFinishWithData)
        XCTAssertNotNil(handler.finishWithDataReceivedParameters?.2)
    }

    fileprivate func thenDataTaskShouldHaveEmbraceHeaders() throws {
        let headers = try XCTUnwrap(dataTask.originalRequest?.allHTTPHeaderFields)
        XCTAssertNotNil(headers["x-emb-id"])
        XCTAssertNotNil(headers["x-emb-st"])
    }
}
