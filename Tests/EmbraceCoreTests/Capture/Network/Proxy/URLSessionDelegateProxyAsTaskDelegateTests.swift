//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceCore
import TestSupport

final class URLSessionDelegateProxyAsTaskDelegateTests: XCTestCase {

    private var urlSessionCaptureService: URLSessionCaptureService!
    private var openTelemetry: MockEmbraceOpenTelemetry!

    private var urlSession: URLSession!
    private var sessionDelegate: URLSessionDelegate!
    private var taskDelegate: URLSessionDelegate!

    static let timeoutQuick = 0.2

    // MARK: - Setup

    override func tearDown() async throws {
        urlSessionCaptureService.swizzlers.forEach { swizzler in
            try? swizzler.unswizzleClassMethod()
            try? swizzler.unswizzleInstanceMethod()
        }
    }

    func givenCaptureServiceInstalled() {
        urlSessionCaptureService = URLSessionCaptureService(options: .init())
        openTelemetry = MockEmbraceOpenTelemetry()

        urlSessionCaptureService.install(otel: openTelemetry)
        urlSessionCaptureService.start()
    }

    func givenURLSession(delegate: URLSessionDelegate? = nil) {
        urlSession = ProxiedURLSessionProvider.with(configuration: .default, delegate: delegate)
//        urlSession = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
    }

    func givenTaskDelegate(_ delegate: URLSessionDelegate = FullyImplementedURLSessionDelegate()) {
        taskDelegate = delegate
    }

    func givenSessionDelegate(_ delegate: URLSessionDelegate = FullyImplementedURLSessionDelegate()) {
        sessionDelegate = delegate
    }

    func mockedURL(string: String, data: Data = Data("Mock Data".utf8)) -> URL {
        var url = URL(string: string)!
        let mockResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        url.mockResponse = .sucessful(withData: data, response: mockResponse)

        return url
    }

    // MARK: - Assertions

    /// Methods dealing with URLSessionTaskDelegate
    func thenTaskDelegateMethodsInvoked(delegate: FullyImplementedURLSessionDelegate) {
        XCTAssertTrue(delegate.didCallCreateTask)
        XCTAssertTrue(delegate.didCallDidCompleteWithError)
    }

    // MARK: - Tests

    func test_taskWithNoDelegate_callsSessionDelegate() throws {
        givenCaptureServiceInstalled()
        givenSessionDelegate()
        givenURLSession(delegate: sessionDelegate)

        let url = mockedURL(string: "https://example.com/")
        let task = urlSession.dataTask(with: url)
        task.resume()

        let sessionDelegate = try XCTUnwrap(sessionDelegate as? FullyImplementedURLSessionDelegate)
        wait(for: [
            sessionDelegate.didReceiveDataExpectation,
            sessionDelegate.didCompleteWithErrorExpectation
        ], timeout: Self.timeoutQuick)
    }

    @available(iOS 15.0, *)
    func test_taskWithDelegate_callsTaskDelegateOnly() throws {
        givenCaptureServiceInstalled()
        givenTaskDelegate()
        givenSessionDelegate()
        givenURLSession(delegate: sessionDelegate)

        let url = mockedURL(string: "https://example.io/aa")
        let task = urlSession.dataTask(with: url)
        let taskDelegate = try XCTUnwrap(taskDelegate as? FullyImplementedURLSessionDelegate)
        task.delegate = taskDelegate
        task.resume()

        let sessionDelegate = try XCTUnwrap(sessionDelegate as? FullyImplementedURLSessionDelegate)
        sessionDelegate.didReceiveDataExpectation.isInverted = true
        sessionDelegate.didCompleteWithErrorExpectation.isInverted = true
        wait(for: [
            sessionDelegate.didReceiveDataExpectation,
            sessionDelegate.didCompleteWithErrorExpectation,
            taskDelegate.didReceiveDataExpectation,
            taskDelegate.didCompleteWithErrorExpectation
        ], timeout: Self.timeoutQuick)
    }

    @available(iOS 15.0, *)
    func test_taskWithDelegate_thatDoesNotImplementMethods_callsSessionDelegateOnly() throws {
        givenCaptureServiceInstalled()
        givenTaskDelegate(NotImplementedURLSessionDelegate())
        givenSessionDelegate()
        givenURLSession(delegate: sessionDelegate)

        let url = mockedURL(string: "https://example.com")
        let task = urlSession.dataTask(with: url)
        task.delegate = try XCTUnwrap(taskDelegate as? URLSessionTaskDelegate)
        task.resume()

        let sessionDelegate = try XCTUnwrap(sessionDelegate as? FullyImplementedURLSessionDelegate)
        wait(for: [
            sessionDelegate.didReceiveDataExpectation,
            sessionDelegate.didCompleteWithErrorExpectation
        ], timeout: Self.timeoutQuick)
    }

    @available(iOS 15.0, *)
    func test_async_taskWithNoDelegate_callsSessionDelegate() async throws {
        givenCaptureServiceInstalled()

        givenSessionDelegate()
        givenURLSession(delegate: sessionDelegate)

        let url = mockedURL(string: "https://example.com")
        let (_, _) = try await urlSession.data(from: url, delegate: nil)

        let sessionDelegate = try XCTUnwrap(sessionDelegate as? FullyImplementedURLSessionDelegate)
        XCTAssertTrue(sessionDelegate.didCallCreateTask)
        XCTAssertTrue(sessionDelegate.didCallDidFinishCollecting)

        // DEV: async/await calls do not call `didCompleteWithError` method as response is handled inline
        XCTAssertFalse(sessionDelegate.didCallDidCompleteWithError)
    }

    @available(iOS 15.0, *)
    func test_async_taskWithDelegate_doesNotCallSessionDelegate() async throws {
        givenCaptureServiceInstalled()

        givenTaskDelegate()
        givenSessionDelegate()
        givenURLSession(delegate: sessionDelegate)

        let url = mockedURL(string: "https://example.com")
        let taskDelegate = try XCTUnwrap(taskDelegate as? FullyImplementedURLSessionDelegate)
        let (_, _) = try await urlSession.data(from: url, delegate: taskDelegate)

        XCTAssertTrue(taskDelegate.didCallCreateTask)
        XCTAssertTrue(taskDelegate.didCallDidFinishCollecting)
        // DEV: async/await calls do not call `didCompleteWithError` method as response is handled inline
        XCTAssertFalse(taskDelegate.didCallDidCompleteWithError)

        let sessionDelegate = try XCTUnwrap(sessionDelegate as? FullyImplementedURLSessionDelegate)
        XCTAssertFalse(sessionDelegate.didCallCreateTask)
        XCTAssertFalse(sessionDelegate.didCallDidFinishCollecting)
        // DEV: async/await calls do not call `didCompleteWithError` method as response is handled inline
        XCTAssertFalse(sessionDelegate.didCallDidCompleteWithError)
    }
}
