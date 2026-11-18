//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import TestSupport
import XCTest

@testable import EmbraceCommonInternal
@testable import EmbraceCore

class DataTaskWithURLAndCompletionSwizzlerTests: SwizzlerTestCase {
    private var session: URLSession!
    private var sut: DataTaskWithURLAndCompletionSwizzler!
    private var sut2: DataTaskWithURLRequestAndCompletionSwizzler!
    private var handler: MockURLSessionTaskHandler!
    private var stubSession: StubURLSession!
    private var url: URL!

    private var dataTask: URLSessionDataTask!

    override func tearDownWithError() throws {
        try? sut.unswizzleInstanceMethod()
        try? sut2.unswizzleInstanceMethod()
        try super.tearDownWithError()
    }

    func testAfterInstall_onExecutingRequest_taskWillBeCreatedInHandler() throws {
        givenDataTaskWithURLAndCompletionSwizzler(baseClass: StubURLSession.self)
        try givenSwizzlingWasDone()
        givenSuccessfulRequest()
        givenStubSession()
        whenInvokingDataTaskWithUrl(completionHandler: { _, _, _ in }, resume: false)
        thenHandlerShouldHaveInvokedCreateWithTask()
    }

    func testAfterInstall_onFinishingRequest_taskWillBeFinishedInHandler() throws {
        givenDataTaskWithURLAndCompletionSwizzler(baseClass: StubURLSession.self)
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
        givenDataTaskWithURLAndCompletionSwizzler(baseClass: StubURLSession.self)
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
        givenDataTaskWithURLAndCompletionSwizzler()
        try givenSwizzlingWasDone()
        givenProxiedUrlSession()
        givenSuccessfulRequest()
        whenInvokingDataTaskWithUrl(completionHandler: { _, _, _ in })
        try thenDataTaskShouldHaveHeaders()
        dataTask.cancel()
    }

    func test_withoutInstall_taskWontBeCreatedInHandler() throws {
        givenDataTaskWithURLAndCompletionSwizzler()
        givenProxiedUrlSession()
        givenSuccessfulRequest()
        whenInvokingDataTaskWithUrl(completionHandler: { _, _, _ in })
        thenHandlerShouldntHaveInvokedCreate()
        dataTask.cancel()
    }
}

extension DataTaskWithURLAndCompletionSwizzlerTests {
    fileprivate func givenDataTaskWithURLAndCompletionSwizzler(baseClass: AnyClass = URLSession.self) {
        handler = MockURLSessionTaskHandler()
        sut = DataTaskWithURLAndCompletionSwizzler(handler: handler, baseClass: baseClass)
        sut2 = DataTaskWithURLRequestAndCompletionSwizzler(handler: handler, baseClass: baseClass)
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
        dataTask = session.dataTask(with: url) { data, response, error in
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

    fileprivate func thenDataTaskShouldHaveHeaders() throws {
        let headers = try XCTUnwrap(dataTask.originalRequest?.allHTTPHeaderFields)
        XCTAssertNotNil(headers["x-emb-id"])
        XCTAssertNotNil(headers["x-emb-st"])
    }
}
