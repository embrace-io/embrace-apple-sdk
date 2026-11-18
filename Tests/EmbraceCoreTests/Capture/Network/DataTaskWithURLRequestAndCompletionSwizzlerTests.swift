//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import TestSupport
import XCTest

@testable import EmbraceCommonInternal
@testable import EmbraceCore

class DataTaskWithURLRequestAndCompletionSwizzlerTests: SwizzlerTestCase {
    private var session: URLSession!
    private var sut: DataTaskWithURLRequestAndCompletionSwizzler!
    private var handler: MockURLSessionTaskHandler!
    private var stubSession: StubURLSession!
    private var request: URLRequest!

    private var dataTask: URLSessionDataTask!

    override func tearDownWithError() throws {
        try? sut.unswizzleInstanceMethod()
        try super.tearDownWithError()
    }

    func testAfterInstall_onExecutingRequest_taskWillBeCreatedInHandler() throws {
        givenDataTaskWithURLRequestSwizzler(baseClass: StubURLSession.self)
        try givenSwizzlingWasDone()
        givenSuccessfulRequest()
        givenStubSession()
        whenInvokingDataTaskWithUrl(completionHandler: { _, _, _ in }, resume: false)
        thenHandlerShouldHaveInvokedCreateWithTask()
    }

    func testAfterInstall_onFinishingRequest_taskWillBeFinishedInHandler() throws {
        givenDataTaskWithURLRequestSwizzler(baseClass: StubURLSession.self)
        try givenSwizzlingWasDone()
        givenSuccessfulRequest()
        givenStubSession()
        var didCallCompletion = false
        whenInvokingDataTaskWithUrl(completionHandler: { _, _, _ in didCallCompletion = true }, resume: false)
        try whenTheSessionFinishesSuccessfully()
        thenHandlerShouldHaveInvokedFinishTask()
        XCTAssertTrue(didCallCompletion)
    }

    func testAfterInstall_onFailedRequest_taskWillBeFinishedInHandler() throws {
        givenDataTaskWithURLRequestSwizzler(baseClass: StubURLSession.self)
        try givenSwizzlingWasDone()
        givenFailedRequest()
        givenStubSession()
        var didCallCompletion = false
        whenInvokingDataTaskWithUrl(completionHandler: { _, _, _ in didCallCompletion = true }, resume: false)
        whenTheSessionFails()
        thenHandlerShouldHaveInvokedFinishTaskWithError()
        XCTAssertTrue(didCallCompletion)
    }

    func test_afterInstall_taskShouldHaveEmbraceHeaders() throws {
        givenDataTaskWithURLRequestSwizzler()
        try givenSwizzlingWasDone()
        givenProxiedUrlSession()
        givenSuccessfulRequest()
        whenInvokingDataTaskWithUrl(completionHandler: { _, _, _ in })
        try thenDataTaskShouldHaveEmbraceHeaders()
        dataTask.cancel()
    }

    func test_withoutInstall_taskWontBeCreatedInHandler() throws {
        givenDataTaskWithURLRequestSwizzler()
        givenProxiedUrlSession()
        givenSuccessfulRequest()
        whenInvokingDataTaskWithUrl(completionHandler: { _, _, _ in })
        thenHandlerShouldntHaveInvokedCreate()
        dataTask.cancel()
    }
}

extension DataTaskWithURLRequestAndCompletionSwizzlerTests {
    fileprivate func givenDataTaskWithURLRequestSwizzler(baseClass: AnyClass = URLSession.self) {
        handler = MockURLSessionTaskHandler()
        sut = DataTaskWithURLRequestAndCompletionSwizzler(handler: handler, baseClass: baseClass)
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

    fileprivate func givenStubSession() {
        stubSession = StubURLSession()
        session = stubSession
    }

    fileprivate func whenTheSessionFinishesSuccessfully() throws {
        let response = HTTPURLResponse(url: URL(string: "https://embrace.io")!, statusCode: 200, httpVersion: nil, headerFields: nil)
        stubSession.completeDataTask(data: Data("Mock Data".utf8), response: response, error: nil)
    }

    fileprivate func whenTheSessionFails() {
        let response = HTTPURLResponse(url: URL(string: "https://embrace.io")!, statusCode: 400, httpVersion: nil, headerFields: nil)
        stubSession.completeDataTask(data: nil, response: response, error: NSError(domain: UUID().uuidString, code: 0))
    }

    fileprivate func whenInvokingDataTaskWithUrl(
        completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void,
        resume: Bool = true
    ) {
        dataTask = session.dataTask(with: request) { data, response, error in
            completionHandler(data, response, error)
        }
        if resume {
            dataTask.resume()
        }
    }

    fileprivate func thenHandlerShouldHaveInvokedCreateWithTask() {
        handler.verifyCreated(dataTask)
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
