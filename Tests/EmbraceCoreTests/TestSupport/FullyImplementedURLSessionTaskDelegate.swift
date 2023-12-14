//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//
    

import Foundation

class FullyImplementedURLSessionTaskDelegate: NSObject, URLSessionTaskDelegate {
    var didCallCreateTask = false
    func urlSession(_ session: URLSession, didCreateTask task: URLSessionTask) {
        didCallCreateTask = true
    }

    var didCallTaskIsWaitingForConnectivity = false
    func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
        didCallTaskIsWaitingForConnectivity = true
    }

    var didCallDidFinishCollecting = false
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didFinishCollecting metrics: URLSessionTaskMetrics) {
        didCallDidFinishCollecting = true
    }

    var didCallDidSendBodyData = false
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didSendBodyData bytesSent: Int64,
                    totalBytesSent: Int64,
                    totalBytesExpectedToSend: Int64) {
        didCallDidSendBodyData = true
    }

    var didCallDidReceiveInformationalResponse = false
    @available(iOS 17.0, *)
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didReceiveInformationalResponse response: HTTPURLResponse) {
        didCallDidReceiveInformationalResponse = true
    }

    var didCallDidCompleteWithError = false
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        didCallDidCompleteWithError = true
    }

    var didCallDidReceiveChallenge = false
    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition,
                                                  URLCredential?) -> Void) {
        didCallDidReceiveChallenge = true
        completionHandler(.performDefaultHandling, nil)
    }

    var didCallWillBeginDelayedRequest = false
    @available(iOS 11.0, *)
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    willBeginDelayedRequest request: URLRequest,
                    completionHandler: @escaping @Sendable (URLSession.DelayedRequestDisposition,
                                                            URLRequest?) -> Void) {
        didCallWillBeginDelayedRequest = true
        completionHandler(.continueLoading, nil)
    }

    var didCallWillPerformHTTPRedirection = false
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        didCallWillPerformHTTPRedirection = true
        completionHandler(nil)
    }

    var didCallTaskWithReceivedAuthenticationChallenge = false
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition,
                                                            URLCredential?) -> Void) {
       didCallTaskWithReceivedAuthenticationChallenge = true
    }

    var didCallNeedNewBodyStream = false
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    needNewBodyStream completionHandler: @escaping @Sendable (InputStream?) -> Void) {
        didCallNeedNewBodyStream = true
    }

    var didCallNeedNewBodyStreamAndCompletion = false
    @available(iOS 17.0, *)
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    needNewBodyStreamFrom offset: Int64,
                    completionHandler: @escaping @Sendable (InputStream?) -> Void) {
        didCallNeedNewBodyStreamAndCompletion = true
    }
}
