//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

extension URLSessionDelegateProxy: URLSessionTaskDelegate {
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didFinishCollecting metrics: URLSessionTaskMetrics) {
        let selector = #selector(
            URLSessionTaskDelegate.urlSession(_:task:didFinishCollecting:)
        )
        if originalDelegateResponds(to: selector),
           let taskDelegate = originalDelegate as? URLSessionTaskDelegate {
            taskDelegate.urlSession?(session, task: task, didFinishCollecting: metrics)
        }
    }

    @available(iOS 16.0, *)
    func urlSession(_ session: URLSession, didCreateTask task: URLSessionTask) {
        let selector = #selector(
            URLSessionTaskDelegate.urlSession(_:didCreateTask:)
        )
        if originalDelegateResponds(to: selector),
           let taskDelegate = originalDelegate as? URLSessionTaskDelegate {
            taskDelegate.urlSession?(session, didCreateTask: task)
        }
    }

    func urlSession(_ session: URLSession,
                    taskIsWaitingForConnectivity task: URLSessionTask) {
        let selector = #selector(
            URLSessionTaskDelegate.urlSession(_:taskIsWaitingForConnectivity:)
        )
        if originalDelegateResponds(to: selector),
           let taskDelegate = originalDelegate as? URLSessionTaskDelegate {
            taskDelegate.urlSession?(session, taskIsWaitingForConnectivity: task)
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
        if originalDelegateResponds(to: selector),
           let taskDelegate = originalDelegate as? URLSessionTaskDelegate {
            taskDelegate.urlSession?(session,
                                     task: task,
                                     didSendBodyData: bytesSent,
                                     totalBytesSent: totalBytesSent,
                                     totalBytesExpectedToSend: totalBytesExpectedToSend)
        }
    }

    @available(iOS 17.0, *)
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didReceiveInformationalResponse response: HTTPURLResponse) {
        let selector = #selector(
            URLSessionTaskDelegate.urlSession(_:task:didReceiveInformationalResponse:)
        )
        if originalDelegateResponds(to: selector),
           let taskDelegate = originalDelegate as? URLSessionTaskDelegate {
            taskDelegate.urlSession?(session, task: task, didReceiveInformationalResponse: response)
        }
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        handler.finish(task: task, data: nil, error: error)
        let selector = #selector(
            URLSessionTaskDelegate.urlSession(_:task:didCompleteWithError:)
        )
        if originalDelegateResponds(to: selector),
           let taskDelegate = originalDelegate as? URLSessionTaskDelegate {
            taskDelegate.urlSession?(session, task: task, didCompleteWithError: error)
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
