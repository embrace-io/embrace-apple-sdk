//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import ObjectiveC.runtime
import XCTest

@testable import EmbraceCore
@testable import EmbraceObjCUtilsInternal

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

    func test_onWillPerformHTTPRedirection_shouldForwardToOriginalDelegate() throws {
        givenProxyWithFullyImplementedOriginalDelegate()
        try whenInvokingWillPerformHTTPRedirection()
        thenOriginalDelegateShouldHaveInvokedWillPerformHTTPRedirection()
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

    func test_onExecutingStreamTaskDidBecome_shouldForwardToOriginalDelegate() throws {
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
        InvocationHelper.invoke(
            on: sut,
            selector: NSSelectorFromString("URLSession:didBecomeInvalidWithError:"),
            parameters: [
                URLSession.shared,
                NSError(domain: NSURLErrorDomain, code: NSURLErrorUnknown)
            ]
        )
    }

    fileprivate func whenInvokingDidCompleteWithError() throws {
        InvocationHelper.invoke(
            on: sut,
            selector: NSSelectorFromString("URLSession:task:didCompleteWithError:"),
            parameters: [
                URLSession.shared,
                aTask(),
                NSError(domain: NSURLErrorDomain, code: NSURLErrorUnknown)
            ]
        )
    }

    fileprivate func whenInvokingDidReceiveChallenge(withExpectation expectation: XCTestExpectation) throws {

        let completionClosure = { (_: URLSession.AuthChallengeDisposition, _: URLCredential) in
            expectation.fulfill()
        }
        let block: AnyObject = unsafeBitCast(completionClosure as @convention(block) (URLSession.AuthChallengeDisposition, URLCredential) -> Void, to: AnyObject.self)

        InvocationHelper.invoke(
            on: sut,
            selector: NSSelectorFromString("URLSession:didReceiveChallenge:completionHandler:"),
            parameters: [
                URLSession.shared,
                URLAuthenticationChallenge(),
                block
            ]
        )
    }

    fileprivate func whenInvokingDidFinishCollectingMetrics() {

        let kclass: AnyClass = NSClassFromString("NSURLSessionTaskMetrics")!
        let metrics =
            kclass.alloc().perform(NSSelectorFromString("init")).takeUnretainedValue() as! URLSessionTaskMetrics

        InvocationHelper.invoke(
            on: sut,
            selector: NSSelectorFromString("URLSession:task:didFinishCollectingMetrics:"),
            parameters: [
                URLSession.shared,
                aTask(),
                metrics
            ]
        )
    }

    fileprivate func whenInvokingDidCreateTask() throws {
        if #available(iOS 16.0, watchOS 10.0, tvOS 16.0, *) {

            InvocationHelper.invoke(
                on: sut,
                selector: NSSelectorFromString("URLSession:didCreateTask:"),
                parameters: [
                    URLSession.shared,
                    aTask()
                ]
            )

        } else {
            throw XCTSkip("This test applies only for iOS 16 and above")
        }
    }

    fileprivate func whenInvokingTaskIsWaitingForConnectivity() {
        InvocationHelper.invoke(
            on: sut,
            selector: NSSelectorFromString("URLSession:taskIsWaitingForConnectivity:"),
            parameters: [
                URLSession.shared,
                aTask()
            ]
        )
    }

    fileprivate func whenInvokingDidSendBodyData() {

        InvocationHelper.invoke(
            on: sut,
            selector: NSSelectorFromString("URLSession:task:didSendBodyData:totalBytesSent:totalBytesExpectedToSend:"),
            parameters: [
                URLSession.shared,
                aTask(),
                Int.random(in: 0...100),
                Int.random(in: 0...100),
                Int.random(in: 0...100)
            ]
        )
    }

    fileprivate func whenInvokingWillPerformHTTPRedirection() throws {
        if #available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, *) {

            let completionClosure = { (_: URLRequest?) in }
            let block: AnyObject = unsafeBitCast(completionClosure as @convention(block) (URLRequest?) -> Void, to: AnyObject.self)

            InvocationHelper.invoke(
                on: sut,
                selector: NSSelectorFromString("URLSession:task:willPerformHTTPRedirection:newRequest:completionHandler:"),
                parameters: [
                    URLSession.shared,
                    aTask(),
                    HTTPURLResponse(),
                    URLRequest(url: URL(string: "https://embrace.io")!),
                    block
                ]
            )
        }
    }

    fileprivate func whenInvokingDidReceiveInformationalResponse() throws {
        if #available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, *) {

            InvocationHelper.invoke(
                on: sut,
                selector: NSSelectorFromString("URLSession:task:didReceiveInformationalResponse:"),
                parameters: [
                    URLSession.shared,
                    aTask(),
                    HTTPURLResponse()
                ]
            )
        } else {
            throw XCTSkip("This test applies only for iOS 17")
        }
    }

    fileprivate func whenInvokingTaskDidBecomeDownloadTask() {

        InvocationHelper.invoke(
            on: sut,
            selector: NSSelectorFromString("URLSession:dataTask:didBecomeDownloadTask:"),
            parameters: [
                URLSession.shared,
                aTask(),
                aDownloadTask()
            ]
        )
    }

    fileprivate func whenInvokingTaskDidBecomeStreamingTask() {

        InvocationHelper.invoke(
            on: sut,
            selector: NSSelectorFromString("URLSession:dataTask:didBecomeStreamingTask:"),
            parameters: [
                URLSession.shared,
                aTask(),
                aStreamTask()
            ]
        )
    }

    fileprivate func whenInvokingDidReceiveData() {

        InvocationHelper.invoke(
            on: sut,
            selector: NSSelectorFromString("URLSession:dataTask:didReceiveData:"),
            parameters: [
                URLSession.shared,
                aTask(),
                Data()
            ]
        )
    }

    fileprivate func whenInvokingDidFinishDownloadingTo() {

        InvocationHelper.invoke(
            on: sut,
            selector: NSSelectorFromString("URLSession:downloadTask:didFinishDownloadingToURL:"),
            parameters: [
                URLSession.shared,
                aDownloadTask(),
                URL(string: "https://embrace.io")!
            ]
        )
    }

    fileprivate func whenInvokingDidResumeAtOffset() {

        InvocationHelper.invoke(
            on: sut,
            selector: NSSelectorFromString("URLSession:downloadTask:didResumeAtOffset:expectedTotalBytes:"),
            parameters: [
                URLSession.shared,
                aDownloadTask(),
                0,
                0
            ]
        )
    }

    fileprivate func whenInvokingReadClosedForStreamingTask() {

        InvocationHelper.invoke(
            on: sut,
            selector: NSSelectorFromString("URLSession:readClosedForStreamTask:"),
            parameters: [
                URLSession.shared,
                aStreamTask()
            ]
        )
    }

    fileprivate func whenInvokingWriteClosedForStreamingTask() {

        InvocationHelper.invoke(
            on: sut,
            selector: NSSelectorFromString("URLSession:writeClosedForStreamTask:"),
            parameters: [
                URLSession.shared,
                aStreamTask()
            ]
        )
    }

    fileprivate func whenInvokingBetterRouteDiscoveredForStreamingTask() {

        InvocationHelper.invoke(
            on: sut,
            selector: NSSelectorFromString("URLSession:betterRouteDiscoveredForStreamTask:"),
            parameters: [
                URLSession.shared,
                aStreamTask()
            ]
        )
    }

    fileprivate func whenInvokingStreamTaskDidBecome() {

        InvocationHelper.invoke(
            on: sut,
            selector: NSSelectorFromString("URLSession:streamTask:didBecomeInputStream:outputStream:"),
            parameters: [
                URLSession.shared,
                aStreamTask(),
                InputStream(),
                OutputStream()
            ]
        )
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
        InvocationHelper.invoke(
            on: sut,
            selector: NSSelectorFromString("URLSession:downloadTask:didWriteData:totalBytesWritten:totalBytesExpectedToWrite:"),
            parameters: [
                URLSession.shared,
                aDownloadTask(),
                0, 0, 0
            ]
        )
    }

    fileprivate func thenOriginalDelegateShouldHaveInvokedWillPerformHTTPRedirection() {
        XCTAssertTrue(originalDelegate.didCallWillPerformHTTPRedirection)
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

@objc final class InvocationHelper: NSObject {

    /// Dynamically invokes an Objective-C method with the given selector and arguments.
    ///
    /// - Parameters:
    ///   - target: The object to invoke the selector on.
    ///   - selector: The Objective-C selector to call.
    ///   - parameters: Array of arguments to pass to the invocation (in order).
    /// - Note:
    ///   - Arguments must match the selector’s expected types and count.
    ///   - The indices start at 2 (`self`, `_cmd` are 0 and 1).
    ///   - This is primarily useful for proxy testing or forwarding.
    @objc static func invoke(
        on target: AnyObject,
        selector: Selector,
        parameters: [Any]
    ) {
        let result = EmbraceInvoke(target, selector, parameters)
        XCTAssertTrue(result)
    }
}
