//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import TestSupport
import XCTest

@testable import EmbraceCommonInternal
@testable import EmbraceCore

// swiftlint:disable force_try

class DataTaskWithURLAndCompletionSwizzlerTests: XCTestCase {
    private var session: URLSession!
    private var sut: DataTaskWithURLAndCompletionSwizzler!
    private var sut2: DataTaskWithURLRequestAndCompletionSwizzler!
    private var handler: MockURLSessionTaskHandler!
    private var url: URL!

    private var dataTask: URLSessionDataTask!

    override func tearDownWithError() throws {
        try? sut.unswizzleInstanceMethod()
    }

    func testAfterInstall_onExecutingRequest_taskWillBeCreatedInHandler() throws {
        let expectation = expectation(description: #function)
        givenDataTaskWithURLAndCompletionSwizzler()
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
        givenDataTaskWithURLAndCompletionSwizzler()
        try givenSwizzlingWasDone()
        givenSuccessfulRequest()
        givenProxiedUrlSession()
        whenInvokingDataTaskWithUrl(completionHandler: { _, _, _ in
            self.thenHandlerShouldHaveInvokedFinishTask()
            expectation.fulfill()
        })
        wait(for: [expectation])
    }

    #if !os(watchOS)
        func testAfterInstall_onFailedRequest_taskWillBeFinishedInHandler() throws {
            let expectation = expectation(description: #function)
            givenDataTaskWithURLAndCompletionSwizzler()
            try givenSwizzlingWasDone()
            givenFailedRequest()
            givenProxiedUrlSession()
            whenInvokingDataTaskWithUrl(completionHandler: { _, _, _ in
                self.thenHandlerShouldHaveInvokedFinishTaskWithError()
                expectation.fulfill()
            })
            wait(for: [expectation])
        }
    #endif

    func test_afterInstall_taskShouldHaveEmbraceHeaders() throws {
        let expectation = expectation(description: #function)
        givenDataTaskWithURLAndCompletionSwizzler()
        try givenSwizzlingWasDone()
        givenProxiedUrlSession()
        givenSuccessfulRequest()
        whenInvokingDataTaskWithUrl(completionHandler: { _, _, _ in
            try! self.thenDataTaskShouldHaveHeaders()
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

extension DataTaskWithURLAndCompletionSwizzlerTests {
    fileprivate func givenDataTaskWithURLAndCompletionSwizzler() {
        handler = MockURLSessionTaskHandler()
        sut = DataTaskWithURLAndCompletionSwizzler(handler: handler)
        sut2 = DataTaskWithURLRequestAndCompletionSwizzler(handler: handler)
    }

    fileprivate func givenSwizzlingWasDone() throws {
        try sut.install()
        try sut2.install()
    }

    fileprivate func givenProxiedUrlSession() {
        session = ProxiedURLSessionProvider.default()
    }

    fileprivate func givenSuccessfulRequest() {
        url = URL(string: "https://embrace.io")!
        let mockData = "Mock Data".data(using: .utf8)!
        let mockResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        url.mockResponse = .successful(withData: mockData, response: mockResponse)
    }

    fileprivate func givenFailedRequest() {
        url = URL(string: "https://embrace.io")!
        let error = NSError(domain: UUID().uuidString, code: 0)
        let mockResponse = HTTPURLResponse(url: url, statusCode: 400, httpVersion: nil, headerFields: nil)!
        url.mockResponse = .failure(withError: error, response: mockResponse)
    }

    fileprivate func whenInvokingDataTaskWithUrl(completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) {
        dataTask = session.dataTask(with: url) { data, response, error in
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

    fileprivate func thenDataTaskShouldHaveHeaders() throws {
        let headers = try XCTUnwrap(dataTask.originalRequest?.allHTTPHeaderFields)
        XCTAssertNotNil(headers["x-emb-id"])
        XCTAssertNotNil(headers["x-emb-st"])
    }
}

// swiftlint:enable force_try
