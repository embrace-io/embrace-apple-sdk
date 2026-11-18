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
    fileprivate typealias Received = (Data?, URLResponse?, Error?)

    private var handler: MockURLSessionTaskHandler!
    private var stubSession: StubURLSession!
    private var sentData: Data?
    private var sentResponse: URLResponse?
    private var sentError: NSError?
    private var request: URLRequest!

    private var dataTask: URLSessionDataTask!

    override func tearDownWithError() throws {
        try? sut.unswizzleInstanceMethod()
        try super.tearDownWithError()
    }

    func testAfterInstall_onExecutingRequest_taskWillBeCreatedInHandler() throws {
        givenDataTaskWithURLRequestSwizzler(baseClass: StubURLSession.self)
        try givenSwizzlingWasDone()
        givenRequest()
        givenStubSession()
        whenInvokingDataTaskWithUrl(completionHandler: { _, _, _ in }, resume: false)
        thenHandlerShouldHaveInvokedCreateWithTask()
    }

    func testAfterInstall_onFinishingRequest_taskWillBeFinishedInHandler() throws {
        givenDataTaskWithURLRequestSwizzler(baseClass: StubURLSession.self)
        try givenSwizzlingWasDone()
        givenRequest()
        givenStubSession()
        var received: Received?
        whenInvokingDataTaskWithUrl(completionHandler: { received = ($0, $1, $2) }, resume: false)
        whenTheSessionFinishesSuccessfully()
        thenHandlerShouldHaveInvokedFinishTask()
        thenTheCompletionShouldHaveReceivedWhatTheSessionSent(received)
    }

    func testAfterInstall_onFailedRequest_taskWillBeFinishedInHandler() throws {
        givenDataTaskWithURLRequestSwizzler(baseClass: StubURLSession.self)
        try givenSwizzlingWasDone()
        givenRequest()
        givenStubSession()
        var received: Received?
        whenInvokingDataTaskWithUrl(completionHandler: { received = ($0, $1, $2) }, resume: false)
        whenTheSessionFails()
        thenHandlerShouldHaveInvokedFinishTaskWithError()
        thenTheCompletionShouldHaveReceivedWhatTheSessionSent(received)
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

    fileprivate func givenRequest() {
        request = URLRequest(url: URL(string: "https://embrace.io")!)
    }

    fileprivate func givenStubSession() {
        StubURLSession.assertOverrides(DataTaskWithURLRequestAndCompletionSwizzler.selector)
        stubSession = StubURLSession()
        session = stubSession
    }

    fileprivate func whenTheSessionFinishesSuccessfully() {
        sentData = Data("Mock Data".utf8)
        sentResponse = HTTPURLResponse(url: URL(string: "https://embrace.io")!, statusCode: 200, httpVersion: nil, headerFields: nil)
        stubSession.completeDataTask(data: sentData, response: sentResponse, error: nil)
    }

    fileprivate func whenTheSessionFails() {
        sentResponse = HTTPURLResponse(url: URL(string: "https://embrace.io")!, statusCode: 400, httpVersion: nil, headerFields: nil)
        sentError = NSError(domain: UUID().uuidString, code: 0)
        stubSession.completeDataTask(data: nil, response: sentResponse, error: sentError)
    }

    fileprivate func thenTheCompletionShouldHaveReceivedWhatTheSessionSent(
        _ received: Received?, file: StaticString = #filePath, line: UInt = #line
    ) {
        guard let received else {
            return XCTFail("The completion wasn't called", file: file, line: line)
        }
        XCTAssertEqual(received.0, sentData, file: file, line: line)
        XCTAssertIdentical(received.1, sentResponse, file: file, line: line)
        XCTAssertIdentical(received.2 as NSError?, sentError, file: file, line: line)
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
        XCTAssertIdentical(handler.finishWithDataReceivedParameters?.0, dataTask)
    }

    fileprivate func thenHandlerShouldHaveInvokedFinishTaskWithError() {
        XCTAssertTrue(handler.didInvokeFinishWithData)
        XCTAssertNotNil(handler.finishWithDataReceivedParameters?.2)
        XCTAssertIdentical(handler.finishWithDataReceivedParameters?.0, dataTask)
    }

    fileprivate func thenDataTaskShouldHaveEmbraceHeaders() throws {
        let headers = try XCTUnwrap(dataTask.originalRequest?.allHTTPHeaderFields)
        XCTAssertNotNil(headers["x-emb-id"])
        XCTAssertNotNil(headers["x-emb-st"])
    }
}
