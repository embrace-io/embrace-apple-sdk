//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import TestSupport
@testable import EmbraceIO

class UploadTaskWithRequestFromFileWithCompletionSwizzlerTests: XCTestCase {
    private var handler: MockURLSessionTaskHandler!
    private var sut: UploadTaskWithRequestFromFileWithCompletionSwizzler!
    private var session: URLSession!
    private var request: URLRequest!

    private var uploadTask: URLSessionDataTask!

    override func tearDownWithError() throws {
        try? sut.unswizzleInstanceMethod()
    }

    func testAfterInstall_onExecutingRequest_taskWillBeCreatedInHandler() throws {
        let expectation = expectation(description: #function)
        givenUploadTaskWithRequestFromFileAndCompletionSwizzler()
        try givenSwizzlingWasDone()
        givenSuccessfulRequest()
        givenProxiedUrlSession()
        whenInvokingUploadTaskWithURLRequestFromFile(completionHandler: { _, _, _ in
            self.thenHandlerShouldHaveInvokedCreateWithTask()
            expectation.fulfill()
        })
        wait(for: [expectation])
    }

    func testAfterInstall_onFinishingRequest_taskWillBeFinishedInHandler() throws {
        let expectation = expectation(description: #function)
        givenUploadTaskWithRequestFromFileAndCompletionSwizzler()
        try givenSwizzlingWasDone()
        givenSuccessfulRequest()
        givenProxiedUrlSession()
        whenInvokingUploadTaskWithURLRequestFromFile(completionHandler: { _, _, _ in
            self.thenHandlerShouldHaveInvokedFinishTask()
            expectation.fulfill()
        })
        wait(for: [expectation])
    }

    func testAfterInstall_onFailedRequest_taskWillBeFinishedInHandler() throws {
        let expectation = expectation(description: #function)
        givenUploadTaskWithRequestFromFileAndCompletionSwizzler()
        try givenSwizzlingWasDone()
        givenFailedRequest()
        givenProxiedUrlSession()
        whenInvokingUploadTaskWithURLRequestFromFile(completionHandler: { _, _, _ in
            self.thenHandlerShouldHaveInvokedFinishTaskWithError()
            expectation.fulfill()
        })
        wait(for: [expectation])
    }

    func test_afterInstall_taskShouldHaveEmbraceHeaders() throws {
        let expectation = expectation(description: #function)
        givenUploadTaskWithRequestFromFileAndCompletionSwizzler()
        try givenSwizzlingWasDone()
        givenProxiedUrlSession()
        givenSuccessfulRequest()
        whenInvokingUploadTaskWithURLRequestFromFile(completionHandler: { _, _, _ in
            // swiftlint:disable force_try
            try! self.thenDataTaskShouldHaveEmbraceHeaders()
            // swiftlint:enable force_try
            expectation.fulfill()
        })
        wait(for: [expectation])
    }

    func test_withoutInstall_taskWontBeCreatedInHandler() throws {
        let expectation = expectation(description: #function)
        givenUploadTaskWithRequestFromFileAndCompletionSwizzler()
        givenProxiedUrlSession()
        givenSuccessfulRequest()
        whenInvokingUploadTaskWithURLRequestFromFile(completionHandler: { _, _, _ in
            self.thenHandlerShouldntHaveInvokedCreate()
            expectation.fulfill()
        })
        wait(for: [expectation])
    }
}

private extension UploadTaskWithRequestFromFileWithCompletionSwizzlerTests {
    func givenUploadTaskWithRequestFromFileAndCompletionSwizzler() {
        handler = MockURLSessionTaskHandler()
        sut = UploadTaskWithRequestFromFileWithCompletionSwizzler(handler: handler)
    }

    func givenSwizzlingWasDone() throws {
        try sut.install()
    }

    func givenSuccessfulRequest() {
        var url = URL(string: "https://embrace.io")!
        let mockData = "Mock Data".data(using: .utf8)!
        let mockResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        url.mockResponse = .sucessful(withData: mockData, response: mockResponse)
        request = URLRequest(url: url)
        request.httpMethod = "POST"
    }

    func givenFailedRequest() {
        var url = URL(string: "https://embrace.io")!
        let error = NSError(domain: UUID().uuidString, code: 0)
        let mockResponse = HTTPURLResponse(url: url, statusCode: 400, httpVersion: nil, headerFields: nil)!
        url.mockResponse = .failure(withError: error, response: mockResponse)
        request = URLRequest(url: url)
        request.httpMethod = "POST"
    }

    func givenProxiedUrlSession() {
        session = ProxiedURLSessionProvider.default()
    }

    func whenInvokingUploadTaskWithURLRequestFromFile(completionHandler: @escaping ((Data?, URLResponse?, Error?) -> Void)) {
        let dummyFile = Bundle.module.url(forResource: "dummy", withExtension: "json", subdirectory: "Mocks")!
        uploadTask = session.uploadTask(with: request, fromFile: dummyFile, completionHandler: { data, response, error in
            completionHandler(data, response, error)
        })
        uploadTask.resume()
    }

    func thenHandlerShouldHaveInvokedCreateWithTask() {
        XCTAssertTrue(handler.didInvokeCreate)
        XCTAssertEqual(handler.createReceivedTask, uploadTask)
    }

    func thenHandlerShouldHaveInvokedFinishTask() {
        XCTAssertTrue(handler.didInvokeFinish)
        XCTAssertNotNil(handler.finishReceivedParameters?.1)
    }

    func thenHandlerShouldHaveInvokedFinishTaskWithError() {
        XCTAssertTrue(handler.didInvokeFinish)
        XCTAssertNotNil(handler.finishReceivedParameters?.2)
    }

    func thenDataTaskShouldHaveEmbraceHeaders() throws {
        let headers = try XCTUnwrap(uploadTask.originalRequest?.allHTTPHeaderFields)
        XCTAssertNotNil(headers["x-emb-id"])
        XCTAssertNotNil(headers["x-emb-st"])
    }

    func thenHandlerShouldntHaveInvokedCreate() {
        XCTAssertFalse(handler.didInvokeCreate)
    }
}
