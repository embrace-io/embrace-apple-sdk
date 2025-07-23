//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import XCTest

class FullyImplementedURLSessionDelegate: NSObject,
    URLSessionTaskDelegate,
    URLSessionDataDelegate,
    URLSessionStreamDelegate,
    URLSessionDownloadDelegate
{
    // MARK: - Task Delegate Methods
    var didCallCreateTask = false
    var didCreateTaskExpectation = XCTestExpectation(description: "called didCreateTask")
    func urlSession(_ session: URLSession, didCreateTask task: URLSessionTask) {
        didCallCreateTask = true
        didCreateTaskExpectation.fulfill()
    }

    var didCallTaskIsWaitingForConnectivity = false
    var taskIsWaitingForConnectivityExpectation = XCTestExpectation(description: "called taskIsWaitingForConnectivity")
    func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
        didCallTaskIsWaitingForConnectivity = true
        taskIsWaitingForConnectivityExpectation.fulfill()
    }

    var didCallDidFinishCollecting = false
    var didFinishCollectingExpectation = XCTestExpectation(description: "called didFinishCollecting")
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didFinishCollecting metrics: URLSessionTaskMetrics
    ) {
        didCallDidFinishCollecting = true
        didFinishCollectingExpectation.fulfill()
    }

    var didCallDidSendBodyData = false
    var didSendBodyDataExpectation = XCTestExpectation(description: "called didSendBodyData")
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        didCallDidSendBodyData = true
        didSendBodyDataExpectation.fulfill()
    }

    var didCallDidReceiveInformationalResponse = false
    var didReceiveInformationalResponseExpectation = XCTestExpectation(
        description: "called didReceiveInformationalResponse")
    @available(iOS 17.0, *)
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceiveInformationalResponse response: HTTPURLResponse
    ) {
        didCallDidReceiveInformationalResponse = true
        didReceiveInformationalResponseExpectation.fulfill()
    }

    var didCallDidCompleteWithError = false
    var didCompleteWithErrorExpectation = XCTestExpectation(description: "called didCompleteWithError")
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        didCallDidCompleteWithError = true
        didCompleteWithErrorExpectation.fulfill()
    }

    var didCallDidReceiveChallenge = false
    var didReceiveChallengeExpectation = XCTestExpectation(description: "called didReceiveChallenge")
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (
            URLSession.AuthChallengeDisposition,
            URLCredential?
        ) -> Void
    ) {
        didCallDidReceiveChallenge = true
        didReceiveChallengeExpectation.fulfill()
        completionHandler(.performDefaultHandling, nil)
    }

    var didCallWillBeginDelayedRequest = false
    @available(iOS 11.0, *)
    var willBeginDelayedRequestExpectation = XCTestExpectation(description: "called willBeginDelayedRequest")
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willBeginDelayedRequest request: URLRequest,
        completionHandler: @escaping @Sendable (
            URLSession.DelayedRequestDisposition,
            URLRequest?
        ) -> Void
    ) {
        didCallWillBeginDelayedRequest = true
        willBeginDelayedRequestExpectation.fulfill()
        completionHandler(.continueLoading, nil)
    }

    var didCallWillPerformHTTPRedirection = false
    var willPerformHTTPRedirectionExpectation = XCTestExpectation(description: "called willPerformHTTPRedirection")
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        didCallWillPerformHTTPRedirection = true
        willPerformHTTPRedirectionExpectation.fulfill()
        completionHandler(nil)
    }

    var didCallTaskWithReceivedAuthenticationChallenge = false
    var taskWithReceivedAuthenticationChallengeExpectation = XCTestExpectation(
        description: "called taskWithReceivedAuthenticationChallenge")
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping @Sendable (
            URLSession.AuthChallengeDisposition,
            URLCredential?
        ) -> Void
    ) {
        didCallTaskWithReceivedAuthenticationChallenge = true
        taskWithReceivedAuthenticationChallengeExpectation.fulfill()
    }

    var didCallNeedNewBodyStream = false
    var needNewBodyStreamExpectation = XCTestExpectation(description: "called needNewBodyStream")
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        needNewBodyStream completionHandler: @escaping @Sendable (InputStream?) -> Void
    ) {
        didCallNeedNewBodyStream = true
        needNewBodyStreamExpectation.fulfill()
        completionHandler(nil)
    }

    var didCallNeedNewBodyStreamAndCompletion = false
    var needNewBodyStreamAndCompletionExpectation = XCTestExpectation(
        description: "called needNewBodyStreamAndCompletion")
    @available(iOS 17.0, *)
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        needNewBodyStreamFrom offset: Int64,
        completionHandler: @escaping @Sendable (InputStream?) -> Void
    ) {
        didCallNeedNewBodyStreamAndCompletion = true
        needNewBodyStreamAndCompletionExpectation.fulfill()
        completionHandler(nil)
    }

    // MARK: - Data Delegate Methods
    var didCallDidReceiveResponseWithHandler = false
    var didReceiveResponseWithHandlerExpectation = XCTestExpectation(
        description: "called didReceiveResponseWithHandler")
    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void
    ) {
        didCallDidReceiveResponseWithHandler = true
        didReceiveResponseWithHandlerExpectation.fulfill()
        completionHandler(.allow)
    }

    var didCallDidBecomeDownloadTask = false
    var didBecomeDownloadTaskExpectation = XCTestExpectation(description: "called didBecomeDownloadTask")
    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didBecome downloadTask: URLSessionDownloadTask
    ) {
        didCallDidBecomeDownloadTask = true
        didBecomeDownloadTaskExpectation.fulfill()
    }

    var didCallDidBecomeStreamTask = false
    var didBecomeStreamTaskExpectation = XCTestExpectation(description: "called didBecomeStreamTask")
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome streamTask: URLSessionStreamTask) {
        didCallDidBecomeStreamTask = true
        didBecomeStreamTaskExpectation.fulfill()
    }

    var didCallDidReceiveData = false
    var didReceiveDataExpectation = XCTestExpectation(description: "called didReceiveData")
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        didCallDidReceiveData = true
        didReceiveDataExpectation.fulfill()
    }

    var didCallWillCacheResponse = false
    var willCacheResponseExpectation = XCTestExpectation(description: "called willCacheResponse")
    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        willCacheResponse proposedResponse: CachedURLResponse,
        completionHandler: @escaping @Sendable (CachedURLResponse?) -> Void
    ) {
        didCallWillCacheResponse = true
        willCacheResponseExpectation.fulfill()
        completionHandler(nil)
    }

    var didCallDidFinishDownloadingTo = false
    var didFinishDownloadingToExpectation = XCTestExpectation(description: "called didFinishDownloadingTo")
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        didCallDidFinishDownloadingTo = true
        didFinishDownloadingToExpectation.fulfill()
    }

    var didCallDidWriteData = false
    var didWriteDataExpectation = XCTestExpectation(description: "called didWriteData")
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        didCallDidWriteData = true
        didWriteDataExpectation.fulfill()
    }

    var didCallDidResumeAtOffset = false
    var didResumeAtOffsetExpectation = XCTestExpectation(description: "called didResumeAtOffset")
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didResumeAtOffset fileOffset: Int64,
        expectedTotalBytes: Int64
    ) {
        didCallDidResumeAtOffset = true
        didResumeAtOffsetExpectation.fulfill()
    }

    // MARK: - Stream Delegate Methods

    var didCallReadClosedFor = false
    var readClosedForExpectation = XCTestExpectation(description: "called readClosedFor")
    func urlSession(_ session: URLSession, readClosedFor streamTask: URLSessionStreamTask) {
        didCallReadClosedFor = true
        readClosedForExpectation.fulfill()
    }

    var didCallWriteClosedFor = false
    var writeClosedForExpectation = XCTestExpectation(description: "called writeClosedFor")
    func urlSession(_ session: URLSession, writeClosedFor streamTask: URLSessionStreamTask) {
        didCallWriteClosedFor = true
        writeClosedForExpectation.fulfill()
    }

    var didCallBetterRouteDiscoveredFor = false
    var betterRouteDiscoveredForExpectation = XCTestExpectation(description: "called betterRouteDiscoveredFor")
    func urlSession(_ session: URLSession, betterRouteDiscoveredFor streamTask: URLSessionStreamTask) {
        didCallBetterRouteDiscoveredFor = true
        betterRouteDiscoveredForExpectation.fulfill()
    }

    var didCallStreamTaskDidBecome = false
    var streamTaskDidBecomeExpectation = XCTestExpectation(description: "called streamTaskDidBecome")
    func urlSession(
        _ session: URLSession,
        streamTask: URLSessionStreamTask,
        didBecome inputStream: InputStream,
        outputStream: OutputStream
    ) {
        didCallStreamTaskDidBecome = true
        streamTaskDidBecomeExpectation.fulfill()
    }

}
