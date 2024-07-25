//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

extension URLSessionDelegateProxy: URLSessionTaskDelegate {
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didFinishCollecting metrics: URLSessionTaskMetrics) {
        handler.finish(task: task, data: nil, error: nil)
        let selector = #selector(
            URLSessionTaskDelegate.urlSession(_:task:didFinishCollecting:)
        )

        invokeDelegates(session: session, selector: selector) { (delegate: URLSessionTaskDelegate) in
            delegate.urlSession?(session, task: task, didFinishCollecting: metrics)
        }
    }

    @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
    func urlSession(_ session: URLSession, didCreateTask task: URLSessionTask) {
        let selector = #selector(
            URLSessionTaskDelegate.urlSession(_:didCreateTask:)
        )

        invokeDelegates(session: session, selector: selector) { (delegate: URLSessionTaskDelegate) in
            delegate.urlSession?(session, didCreateTask: task)
        }
    }

    func urlSession(_ session: URLSession,
                    taskIsWaitingForConnectivity task: URLSessionTask) {
        let selector = #selector(
            URLSessionTaskDelegate.urlSession(_:taskIsWaitingForConnectivity:)
        )

        invokeDelegates(session: session, selector: selector) { (delegate: URLSessionTaskDelegate) in
            delegate.urlSession?(session, taskIsWaitingForConnectivity: task)
        }
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didSendBodyData bytesSent: Int64,
                    totalBytesSent: Int64,
                    totalBytesExpectedToSend: Int64) {
        let selector = #selector(
            URLSessionTaskDelegate.urlSession(_:task:didSendBodyData:totalBytesSent:totalBytesExpectedToSend:)
        )

        invokeDelegates(session: session, selector: selector) { (delegate: URLSessionTaskDelegate) in
            delegate.urlSession?(session,
                                 task: task,
                                 didSendBodyData: bytesSent,
                                 totalBytesSent: totalBytesSent,
                                 totalBytesExpectedToSend: totalBytesExpectedToSend)
        }
    }

    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didReceiveInformationalResponse response: HTTPURLResponse) {
        let selector = #selector(
            URLSessionTaskDelegate.urlSession(_:task:didReceiveInformationalResponse:)
        )

        invokeDelegates(session: session, selector: selector) { (delegate: URLSessionTaskDelegate) in
            delegate.urlSession?(session, task: task, didReceiveInformationalResponse: response)
        }
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        handler.finish(task: task, data: nil, error: error)
        let selector = #selector(
            URLSessionTaskDelegate.urlSession(_:task:didCompleteWithError:)
        )

        invokeDelegates(session: session, selector: selector) { (delegate: URLSessionTaskDelegate) in
            delegate.urlSession?(session, task: task, didCompleteWithError: error)
        }
    }
}

// MARK: Methods with completion block
// We'd have to check the default values for each `completionHandler` first.
// In the meantime, the forwarding mechanism should be enough.
/*
extension URLSessionDelegateProxy {
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    willBeginDelayedRequest request: URLRequest,
                    completionHandler: @escaping @Sendable (URLSession.DelayedRequestDisposition,
                                                            URLRequest?) -> Void) {
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping @Sendable (URLRequest?) -> Void) {

    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition,
                                                            URLCredential?) -> Void) {
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    needNewBodyStream completionHandler: @escaping @Sendable (InputStream?) -> Void) {

    }

    // Note: this should be called inside the above method when possible.
    // @available(iOS 17.0, *)
    // func urlSession(_ session: URLSession, task: URLSessionTask, needNewBodyStreamFrom offset: Int64, completionHandler: @escaping @Sendable (InputStream?) -> Void) {}
}
*/
