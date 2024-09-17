//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import TestSupport
@testable import EmbraceCore

class UploadTaskWithRequestFromFileSwizzlerTests: XCTestCase {
    private var handler: MockURLSessionTaskHandler!
    private var sut: UploadTaskWithRequestFromFileSwizzler!
    private var session: URLSession!
    private var request: URLRequest!

    private var uploadTask: URLSessionDataTask!

    override func tearDownWithError() throws {
        try? sut.unswizzleInstanceMethod()
    }

    func test_afterInstall_taskWillBeCreatedInHandler() throws {
        givenUploadTaskWithURLRequestAndCompletionSwizzler()
        try givenSwizzlingWasDone()
        givenSuccessfulRequest()
        givenProxiedUrlSession()
        whenInvokingUploadTaskWithRequestFromFile()
        thenHandlerShouldHaveInvokedCreateWithTask()
    }

    func test_afterInstall_taskShouldHaveEmbraceHeaders() throws {
        givenUploadTaskWithURLRequestAndCompletionSwizzler()
        try givenSwizzlingWasDone()
        givenSuccessfulRequest()
        givenProxiedUrlSession()
        whenInvokingUploadTaskWithRequestFromFile()
        try thenTaskShouldHaveEmbraceHeaders()
    }

    func test_withoutInstall_taskWontBeCreatedInHandler() {
        givenUploadTaskWithURLRequestAndCompletionSwizzler()
        givenSuccessfulRequest()
        givenProxiedUrlSession()
        whenInvokingUploadTaskWithRequestFromFile()
        thenHandlerShouldntHaveInvokedCreate()
    }
}

private extension UploadTaskWithRequestFromFileSwizzlerTests {
    func givenUploadTaskWithURLRequestAndCompletionSwizzler() {
        handler = MockURLSessionTaskHandler()
        sut = UploadTaskWithRequestFromFileSwizzler(handler: handler)
    }

    func givenSwizzlingWasDone() throws {
        try sut.install()
    }

    func givenProxiedUrlSession() {
        session = ProxiedURLSessionProvider.default()
    }

    func givenSuccessfulRequest() {
        var url = URL(string: "https://embrace.io")!
        let mockData = "Mock Data".data(using: .utf8)!
        let mockResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        url.mockResponse = .successful(withData: mockData, response: mockResponse)
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

    func whenInvokingUploadTaskWithRequestFromFile() {
        let dummyFile = Bundle.module.url(forResource: "dummy", withExtension: "json", subdirectory: "Mocks")!
        uploadTask = session.uploadTask(with: request, fromFile: dummyFile)
        uploadTask.resume()
    }

    func thenHandlerShouldHaveInvokedCreateWithTask() {
        XCTAssertTrue(handler.didInvokeCreate)
        XCTAssertEqual(handler.createReceivedTask, uploadTask)
    }

    func thenHandlerShouldntHaveInvokedCreate() {
        XCTAssertFalse(handler.didInvokeCreate)
    }

    func thenTaskShouldHaveEmbraceHeaders() throws {
        let headers = try XCTUnwrap(uploadTask.originalRequest?.allHTTPHeaderFields)
        XCTAssertNotNil(headers["x-emb-id"])
        XCTAssertNotNil(headers["x-emb-st"])
    }
}
