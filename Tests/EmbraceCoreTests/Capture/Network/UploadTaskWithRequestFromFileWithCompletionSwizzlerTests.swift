//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import TestSupport
import XCTest

@testable import EmbraceCore

class UploadTaskWithRequestFromFileWithCompletionSwizzlerTests: XCTestCase, @unchecked Sendable {
    private var handler: MockURLSessionTaskHandler!
    private var sut: UploadTaskWithRequestFromFileWithCompletionSwizzler!
    private var session: URLSession!
    private var request: URLRequest!

    private var uploadTask: URLSessionDataTask!

    override func tearDownWithError() throws {
        try? sut.unswizzleInstanceMethod()
    }

    func testAfterInstall_onExecutingRequest_taskWillBeCreatedInHandler() async throws {
        givenUploadTaskWithRequestFromFileAndCompletionSwizzler()
        try await givenSwizzlingWasDone()
        givenSuccessfulRequest()
        givenProxiedUrlSession()
        await whenInvokingUploadTaskWithURLRequestFromFile()
        thenHandlerShouldHaveInvokedCreateWithTask()
    }

    func testAfterInstall_onFinishingRequest_taskWillBeFinishedInHandler() async throws {
        givenUploadTaskWithRequestFromFileAndCompletionSwizzler()
        try await givenSwizzlingWasDone()
        givenSuccessfulRequest()
        givenProxiedUrlSession()
        await whenInvokingUploadTaskWithURLRequestFromFile()
        thenHandlerShouldHaveInvokedFinishTask()
    }

    #if !os(watchOS)
        func testAfterInstall_onFailedRequest_taskWillBeFinishedInHandler() async throws {
            givenUploadTaskWithRequestFromFileAndCompletionSwizzler()
            try await givenSwizzlingWasDone()
            givenFailedRequest()
            givenProxiedUrlSession()
            await whenInvokingUploadTaskWithURLRequestFromFile()
            thenHandlerShouldHaveInvokedFinishTaskWithError()
        }
    #endif

    func test_afterInstall_taskShouldHaveEmbraceHeaders() async throws {
        givenUploadTaskWithRequestFromFileAndCompletionSwizzler()
        try await givenSwizzlingWasDone()
        givenProxiedUrlSession()
        givenSuccessfulRequest()
        await whenInvokingUploadTaskWithURLRequestFromFile()
        try! thenDataTaskShouldHaveEmbraceHeaders()
    }

    func test_withoutInstall_taskWontBeCreatedInHandler() async throws {
        givenUploadTaskWithRequestFromFileAndCompletionSwizzler()
        givenProxiedUrlSession()
        givenSuccessfulRequest()
        await whenInvokingUploadTaskWithURLRequestFromFile()
        thenHandlerShouldntHaveInvokedCreate()
    }
}

extension UploadTaskWithRequestFromFileWithCompletionSwizzlerTests {
    fileprivate func givenUploadTaskWithRequestFromFileAndCompletionSwizzler() {
        handler = MockURLSessionTaskHandler()
        sut = UploadTaskWithRequestFromFileWithCompletionSwizzler(handler: handler)
    }

    @MainActor
    fileprivate func givenSwizzlingWasDone() async throws {
        try sut.install()
    }

    fileprivate func givenSuccessfulRequest() {
        var url = URL(string: "https://embrace.io")!
        let mockData = "Mock Data".data(using: .utf8)!
        let mockResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        url.mockResponse = .successful(withData: mockData, response: mockResponse)
        request = URLRequest(url: url)
        request.httpMethod = "POST"
    }

    fileprivate func givenFailedRequest() {
        var url = URL(string: "https://embrace.io")!
        let error = NSError(domain: UUID().uuidString, code: 0)
        let mockResponse = HTTPURLResponse(url: url, statusCode: 400, httpVersion: nil, headerFields: nil)!
        url.mockResponse = .failure(withError: error, response: mockResponse)
        request = URLRequest(url: url)
        request.httpMethod = "POST"
    }

    fileprivate func givenProxiedUrlSession() {
        session = ProxiedURLSessionProvider.default()
    }

    fileprivate func whenInvokingUploadTaskWithURLRequestFromFile() async {
        let dummyFile = Bundle.module.url(forResource: "dummy", withExtension: "json", subdirectory: "Mocks")!
        await withCheckedContinuation { continuation in
            uploadTask = session.uploadTask(
                with: request,
                fromFile: dummyFile,
                completionHandler: { data, response, error in
                    continuation.resume()
                    //completionHandler(data, response, error)
                })
            uploadTask.resume()
        }
    }

    fileprivate func thenHandlerShouldHaveInvokedCreateWithTask() {
        XCTAssertTrue(handler.didInvokeCreate)
        XCTAssertEqual(handler.createReceivedTask, uploadTask)
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
        let headers = try XCTUnwrap(uploadTask.originalRequest?.allHTTPHeaderFields)
        XCTAssertNotNil(headers["x-emb-id"])
        XCTAssertNotNil(headers["x-emb-st"])
    }

    fileprivate func thenHandlerShouldntHaveInvokedCreate() {
        XCTAssertFalse(handler.didInvokeCreate)
    }
}
