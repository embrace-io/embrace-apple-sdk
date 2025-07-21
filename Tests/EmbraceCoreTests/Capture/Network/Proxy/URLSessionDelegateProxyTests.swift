//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceCore
@testable @_implementationOnly import EmbraceObjCUtilsInternal

class URLSessionDelegateProxyTests: XCTestCase {
    private var originalDelegate: FullyImplementedURLSessionDelegate!
    private var sut: EMBURLSessionDelegateProxy!
    private var handler: MockURLSessionTaskHandler!

    func test_onExecuteDidCompleteWithError_shouldCallBothProxyAndOriginalDelegate() throws {
        givenProxyWithFullyImplementedOriginalDelegate()
        // This method is implemented in both proxy and original delegate.
        try whenInvokingDidCompleteWithError()
        thenOriginalDelegateShouldHaveInvokedDidCompleteWithError()
        thenProxyShouldHaveFinishedTaskInHandler()
    }

    func test_onExecutingNonImplementedMethodInProxy_shouldForwardToOriginalDelegate() throws {
        let expectation = expectation(description: #function)
        givenProxyWithFullyImplementedOriginalDelegate()
        // This is a non-implemented method in the proxy
        try whenInvokingDidReceiveChallenge(withExpectation: expectation)
        thenOriginalDelegateShouldHaveInvokedDidReceiveChallenge()
        wait(for: [expectation])
    }
}

// MARK: - Test Forwarding to each TaskDelegate Method
extension URLSessionDelegateProxyTests {
    func test_onExecutingDidFinishCollecting_shouldForwardToOriginalDelegate() {
        givenProxyWithFullyImplementedOriginalDelegate()
        whenInvokingDidFinishCollectingMetrics()
        thenOriginalDelegateShouldHaveInvokedDidFinishCollectingMetrics()
    }

    func test_onExecutingDidCreateTask_shouldForwardToOriginalDelegate() throws {
        givenProxyWithFullyImplementedOriginalDelegate()
        try whenInvokingDidCreateTask()
        thenOriginalDelegateShouldHaveInvokedDidCreateTask()
    }

    func test_onExecutingTaskIsWaitingForConnectivity_shouldForwardToOriginalDelegate() {
        givenProxyWithFullyImplementedOriginalDelegate()
        whenInvokingTaskIsWaitingForConnectivity()
        thenOriginalDelegateShouldHaveInvokedTaskIsWaitingForConnectivity()
    }

    func test_onExecutingDidSendBodyData_shouldForwardToOriginalDelegate() {
        givenProxyWithFullyImplementedOriginalDelegate()
        whenInvokingDidSendBodyData()
        thenOriginalDelegateShouldHaveInvokedDidSendBodyData()
    }

    func test_onExecutingDidReceiveInformationalResponse_shouldForwardToOriginalDelegate() throws {
        givenProxyWithFullyImplementedOriginalDelegate()
        try whenInvokingDidReceiveInformationalResponse()
        thenOriginalDelegateShouldHaveInvokedDidReceiveInformationalResponse()
    }
}

// MARK: - Test Forwarding to each TaskDelegate Method
extension URLSessionDelegateProxyTests {
    func test_onExecutingTaskDidBecomeDownloadTask_shouldForwardToOriginalDelegate() {
        givenProxyWithFullyImplementedOriginalDelegate()
        whenInvokingTaskDidBecomeDownloadTask()
        thenOriginalDelegateShouldHaveInvokedTaskDidBecomeDownloadTask()
    }

    func test_onExecutingTaskDidBecomeStreamingTask_shouldForwardToOriginalDelegate() {
        givenProxyWithFullyImplementedOriginalDelegate()
        whenInvokingTaskDidBecomeDownloadTask()
        thenOriginalDelegateShouldHaveInvokedTaskDidBecomeDownloadTask()
    }

    func test_onExecutingDidReceiveData_shouldForwardToOriginalDelegate() {
        givenProxyWithFullyImplementedOriginalDelegate()
        whenInvokingDidReceiveData()
        thenOriginalDelegateShouldHaveInvokedDidReceiveData()
    }
}

// MARK: - Test Forwarding to each Download Task Method
extension URLSessionDelegateProxyTests {
    func test_onExecutingDidFinishDownloadingTo_shouldForwardToOriginalDelegate() {
        givenProxyWithFullyImplementedOriginalDelegate()
        whenInvokingDidFinishDownloadingTo()
        thenOriginalDelegateShouldHaveInvokedDidFinishDownloadingTo()
    }

    func test_onExecutingDidWriteData_shouldForwardToOriginalDelegate() {
        givenProxyWithFullyImplementedOriginalDelegate()
        whenInvokingDidWriteData()
        thenOriginalDelegateShouldHaveInvokedDidWriteData()
    }

    func test_onExecutingDidResumeAtOffset_shouldForwardToOriginalDelegate() {
        givenProxyWithFullyImplementedOriginalDelegate()
        whenInvokingDidResumeAtOffset()
        thenOriginalDelegateShouldHaveInvokedDidResumeAtOffset()
    }
}

// MARK: - Test Forwarding to each Stream Task Method
extension URLSessionDelegateProxyTests {
    func test_onExecutingReadClosedForStreamingTask_shouldForwardToOriginalDelegate() {
        givenProxyWithFullyImplementedOriginalDelegate()
        whenInvokingReadClosedForStreamingTask()
        thenOriginalDelegateShouldHaveInvokedReadClosedForStreamingTask()
    }

    func test_onExecutingWriteClosedForStreamingTask_shouldForwardToOriginalDelegate() {
        givenProxyWithFullyImplementedOriginalDelegate()
        whenInvokingWriteClosedForStreamingTask()
        thenOriginalDelegateShouldHaveInvokedWriteClosedForStreamingTask()
    }

    func test_onExecutingBetterRouteDiscoveredForStreamingTask_shouldForwardToOriginalDelegate() {
        givenProxyWithFullyImplementedOriginalDelegate()
        whenInvokingBetterRouteDiscoveredForStreamingTask()
        thenOriginalDelegateShouldHaveInvokedBetterRouteDiscoveredForStreamingTask()
    }

    func test_onExecutingStreamTaskDidBecome_shouldForwardToOriginalDelegate() {
        givenProxyWithFullyImplementedOriginalDelegate()
        whenInvokingStreamTaskDidBecome()
        thenOriginalDelegateShouldHaveInvokedStreamTaskDidBecome()
    }
}

extension URLSessionDelegateProxyTests {
    fileprivate func givenProxyWithFullyImplementedOriginalDelegate() {
        handler = .init()
        originalDelegate = .init()
        sut = EMBURLSessionDelegateProxy(delegate: originalDelegate, handler: handler)
    }

    fileprivate func whenInvokingDidBecomeInvalidWithError() throws {
        try XCTUnwrap(sut as URLSessionDelegate)
            .urlSession?(
                .shared,
                didBecomeInvalidWithError: nil
            )
    }

    fileprivate func whenInvokingDidCompleteWithError() throws {
        try XCTUnwrap(sut as URLSessionDataDelegate)
            .urlSession?(
                .shared,
                task: aTask(),
                didCompleteWithError: NSError(domain: NSURLErrorDomain, code: NSURLErrorUnknown))
    }

    fileprivate func whenInvokingDidReceiveChallenge(withExpectation expectation: XCTestExpectation) throws {
        try XCTUnwrap(sut as URLSessionDataDelegate).urlSession?(
            .shared,
            didReceive: .init(),
            completionHandler: { _, _ in
                expectation.fulfill()
            })
    }

    fileprivate func whenInvokingDidFinishCollectingMetrics() {
        (sut as URLSessionTaskDelegate).urlSession?(
            .shared,
            task: aTask(),
            didFinishCollecting: .init())
    }

    fileprivate func whenInvokingDidCreateTask() throws {
        if #available(iOS 16.0, watchOS 10.0, tvOS 16.0, *) {
            (sut as URLSessionTaskDelegate).urlSession?(.shared, didCreateTask: aTask())
        } else {
            throw XCTSkip("This test applies only for iOS 16 and above")
        }
    }

    fileprivate func whenInvokingTaskIsWaitingForConnectivity() {
        (sut as URLSessionTaskDelegate).urlSession?(.shared, taskIsWaitingForConnectivity: aTask())
    }

    fileprivate func whenInvokingDidSendBodyData() {
        (sut as URLSessionTaskDelegate).urlSession?(
            .shared,
            task: aTask(),
            didSendBodyData: .random(in: 0...100),
            totalBytesSent: .random(in: 0...100),
            totalBytesExpectedToSend: .random(in: 0...100))
    }

    fileprivate func whenInvokingDidReceiveInformationalResponse() throws {
        if #available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, *) {
            (sut as URLSessionTaskDelegate).urlSession?(
                .shared,
                task: aTask(),
                didReceiveInformationalResponse: .init())
        } else {
            throw XCTSkip("This test applies only for iOS 17")
        }
    }

    fileprivate func whenInvokingTaskDidBecomeDownloadTask() {
        (sut as URLSessionDataDelegate).urlSession?(.shared, dataTask: aTask(), didBecome: aDownloadTask())
    }

    fileprivate func whenInvokingTaskDidBecomeStreamingTask() {
        (sut as URLSessionDataDelegate).urlSession?(.shared, dataTask: aTask(), didBecome: aStreamTask())
    }

    fileprivate func whenInvokingDidReceiveData() {
        (sut as URLSessionDataDelegate).urlSession?(.shared, dataTask: aTask(), didReceive: Data())
    }

    fileprivate func whenInvokingDidFinishDownloadingTo() {
        (sut as URLSessionDownloadDelegate).urlSession(
            .shared,
            downloadTask: aDownloadTask(),
            didFinishDownloadingTo: .init(string: "https://embrace.io")!)
    }

    fileprivate func whenInvokingDidResumeAtOffset() {
        (sut as URLSessionDownloadDelegate).urlSession?(
            .shared,
            downloadTask: aDownloadTask(),
            didResumeAtOffset: 0,
            expectedTotalBytes: 0)
    }

    fileprivate func whenInvokingReadClosedForStreamingTask() {
        (sut as URLSessionStreamDelegate).urlSession?(
            .shared,
            readClosedFor: aStreamTask())
    }

    fileprivate func whenInvokingWriteClosedForStreamingTask() {
        (sut as URLSessionStreamDelegate).urlSession?(.shared, writeClosedFor: aStreamTask())
    }

    fileprivate func whenInvokingBetterRouteDiscoveredForStreamingTask() {
        (sut as URLSessionStreamDelegate).urlSession?(.shared, betterRouteDiscoveredFor: aStreamTask())
    }

    fileprivate func whenInvokingStreamTaskDidBecome() {
        (sut as URLSessionStreamDelegate).urlSession?(
            .shared,
            streamTask: aStreamTask(),
            didBecome: .init(),
            outputStream: .init())
    }

    fileprivate func thenOriginalDelegateShouldHaveInvokedWriteClosedForStreamingTask() {
        XCTAssertTrue(originalDelegate.didCallWriteClosedFor)
    }

    fileprivate func thenOriginalDelegateShouldHaveInvokedBetterRouteDiscoveredForStreamingTask() {
        XCTAssertTrue(originalDelegate.didCallBetterRouteDiscoveredFor)
    }

    fileprivate func thenOriginalDelegateShouldHaveInvokedStreamTaskDidBecome() {
        XCTAssertTrue(originalDelegate.didCallStreamTaskDidBecome)
    }

    fileprivate func thenOriginalDelegateShouldHaveInvokedReadClosedForStreamingTask() {
        XCTAssertTrue(originalDelegate.didCallReadClosedFor)
    }

    fileprivate func thenOriginalDelegateShouldHaveInvokedDidResumeAtOffset() {
        XCTAssertTrue(originalDelegate.didCallDidResumeAtOffset)
    }

    fileprivate func thenOriginalDelegateShouldHaveInvokedDidFinishDownloadingTo() {
        XCTAssertTrue(originalDelegate.didCallDidFinishDownloadingTo)
    }

    fileprivate func thenOriginalDelegateShouldHaveInvokedDidReceiveData() {
        XCTAssertTrue(originalDelegate.didCallDidReceiveData)
    }

    fileprivate func thenOriginalDelegateShouldHaveInvokedTaskDidBecomeStreamingTask() {
        XCTAssertTrue(originalDelegate.didCallDidBecomeStreamTask)
    }

    fileprivate func whenInvokingDidWriteData() {
        (sut as URLSessionDownloadDelegate).urlSession?(
            .shared,
            downloadTask: aDownloadTask(),
            didWriteData: 0,
            totalBytesWritten: 0,
            totalBytesExpectedToWrite: 0)
    }

    fileprivate func thenOriginalDelegateShouldHaveInvokedDidWriteData() {
        XCTAssertTrue(originalDelegate.didCallDidWriteData)
    }

    fileprivate func thenOriginalDelegateShouldHaveInvokedTaskDidBecomeDownloadTask() {
        XCTAssertTrue(originalDelegate.didCallDidBecomeDownloadTask)
    }

    fileprivate func thenOriginalDelegateShouldHaveInvokedDidReceiveInformationalResponse() {

    }

    fileprivate func thenOriginalDelegateShouldHaveInvokedDidSendBodyData() {
        XCTAssertTrue(originalDelegate.didCallDidSendBodyData)
    }

    fileprivate func thenOriginalDelegateShouldHaveInvokedTaskIsWaitingForConnectivity() {
        XCTAssertTrue(originalDelegate.didCallTaskIsWaitingForConnectivity)
    }

    fileprivate func thenOriginalDelegateShouldHaveInvokedDidCreateTask() {
        XCTAssertTrue(originalDelegate.didCallCreateTask)
    }

    fileprivate func thenOriginalDelegateShouldHaveInvokedDidFinishCollectingMetrics() {
        XCTAssertTrue(originalDelegate.didCallDidFinishCollecting)
    }

    fileprivate func thenOriginalDelegateShouldHaveInvokedDidReceiveChallenge() {
        XCTAssertTrue(originalDelegate.didCallDidReceiveChallenge)
    }

    fileprivate func thenOriginalDelegateShouldHaveInvokedDidCompleteWithError() {
        XCTAssertTrue(originalDelegate.didCallDidCompleteWithError)
    }

    fileprivate func thenProxyShouldHaveFinishedTaskInHandler() {
        XCTAssertTrue(handler.didInvokeFinishWithData)
    }

    fileprivate func aTask() -> URLSessionDataTask {
        let url = URL(string: "https://embrace.io")!
        let request = URLRequest(url: url)
        return URLSession.shared.dataTask(with: request)
    }

    fileprivate func aDownloadTask() -> URLSessionDownloadTask {
        let url = URL(string: "https://embrace.io")!
        let request = URLRequest(url: url)
        return URLSession.shared.downloadTask(with: request)
    }

    fileprivate func aStreamTask() -> URLSessionStreamTask {
        URLSession.shared.streamTask(withHostName: "embrace.io", port: 8000)
    }

    fileprivate func aResponse() -> URLResponse { .init() }
}
