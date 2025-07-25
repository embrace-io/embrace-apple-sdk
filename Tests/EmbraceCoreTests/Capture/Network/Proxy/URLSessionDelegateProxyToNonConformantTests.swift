//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import TestSupportObjc
import XCTest

@testable import EmbraceCore
@testable @_implementationOnly import EmbraceObjCUtilsInternal

/// The purpose of these tests is to verify that the forwarding mechanism in `URLSessionDelegateProxy` works correctly for cases where an object (aka `NSObject`)
/// implements multiple methods (or responds to multiple selectors) of `NSURLSessionDelegate` but does not conform to the subprotocols (such as `NSURLSessionDataDelegate` or
/// `NSURLSessionTaskDelegate`) to which these methods belong. This scenario seems to be relatively common in Objective-C codebases.
///
/// To achieve this, we created a class named `URLSessionDelegateImplementerButWithoutConforming` (in `TestSupportObjc`), which simulates this behavior.
/// This class not only avoids conforming to the protocols, but it also does not expose the relevant methods in its header (`.h`) file.
/// Therefore, the goal is to confirm that the redirection mechanism functions properly even under the worst-case conditions
class URLSessionDelegateProxyToNonConformantTests: XCTestCase {
    private var originalDelegate: URLSessionDelegateImplementerButWithoutConforming?
    private var sut: EMBURLSessionDelegateProxy!
    private var handler: MockURLSessionTaskHandler!
    private var dataTask: URLSessionDataTask!
    private var urlSession: URLSession!

    func testShouldForwardToDidReceiveDataOnNonConformingObjectIfRespondsToTheSelector() throws {
        let randomData = try XCTUnwrap(UUID().uuidString.data(using: .utf8))
        givenProxyContainingDelegateImplemetingMethodsButNotConformingToSpecificProtocols()
        whenInvokingDidReceiveData(randomData)
        try thenDidReceiveDataShouldBeCalledOnDelegate()
        thenTaskShouldHaveAddedEmbraceData(equalsTo: randomData)
    }

    func testShouldForwardToDidFinishCollectiongMetricsOnNonConformingObjectIfRespondsToTheSelector() throws {
        givenProxyContainingDelegateImplemetingMethodsButNotConformingToSpecificProtocols()
        whenInvokingDidFinishCollectingMetrics()
        try thenDidFinishCollectingMetricsShouldBeCalledOnDelegate()
        thenHandlerShouldHaveInvokedFinishWithBodySize()
    }

    func testShouldForwardToDidCompleteWithErrorOnNonConformingObjectIfRespondsToTheSelector() throws {
        givenProxyContainingDelegateImplemetingMethodsButNotConformingToSpecificProtocols()
        whenInvokindDidCompleteWithError()
        try thenDidCompleteWithErrorShouldBeCalledOnDelegate()
        thenHandlerShouldHaveInvokedFinishWithData()
    }

    func testShouldForwardToDidFinishDownloadingToURLOnNonConformingObjectIfRespondsToTheSelector() throws {
        givenProxyContainingDelegateImplemetingMethodsButNotConformingToSpecificProtocols()
        try whenInvokingDidFinishDownloadingToURL()
        try thenDidFinishDownloadingToURLShouldBeCalledOnDelegate()
    }

    func testShouldForwardToDidBecomeInvalidWithErrorOnNonConformingObjectIfRespondsToTheSelector() throws {
        givenProxyContainingDelegateImplemetingMethodsButNotConformingToSpecificProtocols()
        whenInvokingDidBecomeInvalidWithError()
        try thenDidBecomeInvalidWithErrorShouldBeCalledOnDelegate()
    }
}

extension URLSessionDelegateProxyToNonConformantTests {
    fileprivate func givenProxyContainingDelegateImplemetingMethodsButNotConformingToSpecificProtocols() {
        originalDelegate = URLSessionDelegateImplementerButWithoutConforming()
        handler = .init()
        urlSession = URLSession(configuration: .ephemeral)
        sut = EMBURLSessionDelegateProxy(delegate: originalDelegate, handler: handler)
    }

    fileprivate func whenInvokingDidReceiveData(_ data: Data) {
        dataTask = aDataTask()
        (sut as URLSessionDataDelegate).urlSession?(
            urlSession,
            dataTask: dataTask,
            didReceive: data
        )
    }

    fileprivate func whenInvokingDidBecomeInvalidWithError() {
        sut.urlSession(
            urlSession,
            didBecomeInvalidWithError: NSError(
                domain: .random(),
                code: .random(),
                userInfo: [:]
            )
        )
    }

    fileprivate func whenInvokingDidFinishCollectingMetrics() {
        sut.urlSession(
            urlSession,
            task: aDataTask(),
            didFinishCollecting: URLSessionTaskMetrics()
        )
    }

    fileprivate func whenInvokindDidCompleteWithError() {
        sut.urlSession(
            urlSession,
            task: aDataTask(),
            didCompleteWithError: NSError(
                domain: .random(),
                code: .random()
            )
        )
    }

    fileprivate func whenInvokingDidFinishDownloadingToURL() throws {
        sut.urlSession(
            urlSession,
            downloadTask: aDownloadTask(),
            didFinishDownloadingTo: try XCTUnwrap(URL(string: "https://embrace.io"))
        )
    }

    fileprivate func thenDidFinishDownloadingToURLShouldBeCalledOnDelegate() throws {
        XCTAssertTrue(try XCTUnwrap(originalDelegate).didInvokedDidFinishDownloadingToURL)
    }

    fileprivate func thenDidCompleteWithErrorShouldBeCalledOnDelegate() throws {
        XCTAssertTrue(try XCTUnwrap(originalDelegate).didInvokedDidCompleteWithError)
    }

    fileprivate func thenDidFinishCollectingMetricsShouldBeCalledOnDelegate() throws {
        XCTAssertTrue(try XCTUnwrap(originalDelegate).didInvokeDidFinishCollectingMetrics)
    }

    fileprivate func thenDidBecomeInvalidWithErrorShouldBeCalledOnDelegate() throws {
        XCTAssertTrue(try XCTUnwrap(originalDelegate).didInvokeDidBecomeInvalidWithError)
    }

    fileprivate func thenDidReceiveDataShouldBeCalledOnDelegate() throws {
        XCTAssertTrue(try XCTUnwrap(originalDelegate).didInvokeDidReceiveData)
    }

    fileprivate func thenTaskShouldHaveAddedEmbraceData(equalsTo data: Data) {
        XCTAssertEqual(handler.receivedData, data)
    }

    fileprivate func thenHandlerShouldHaveInvokedFinishWithData() {
        XCTAssertTrue(handler.didInvokeFinishWithData)
    }

    fileprivate func thenHandlerShouldHaveInvokedFinishWithBodySize() {
        XCTAssertTrue(handler.didInvokeFinishWithBodySize)
    }
}

extension URLSessionDelegateProxyToNonConformantTests {
    fileprivate func aDataTask() -> URLSessionDataTask {
        let url = URL(string: "https://embrace.io")!
        let request = URLRequest(url: url)
        return urlSession.dataTask(with: request)
    }

    fileprivate func aDownloadTask() -> URLSessionDownloadTask {
        let url = URL(string: "https://embrace.io")!
        let request = URLRequest(url: url)
        return urlSession.downloadTask(with: request)
    }
}
