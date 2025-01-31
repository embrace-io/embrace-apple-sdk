//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceObjCUtilsInternal

class EmbraceDummyURLSessionDelegate: NSObject, URLSessionDelegate {}

class URLSessionDelegateProxy: NSObject {
    var originalDelegate: URLSessionDelegate?

    /// This helps to determine if, during the creation of the `URLSessionDelegateProxy`,
    /// another player or SDK has already swizzled or proxied NSURLSession/URLSession.
    weak var swizzledDelegate: URLSessionDelegate?
    let handler: URLSessionTaskHandler

    // Check if this is necessary
    override var description: String {
        return originalDelegate?.description ?? String(describing: type(of: self))
    }

    init(originalDelegate: URLSessionDelegate?, handler: URLSessionTaskHandler) {
        self.originalDelegate = originalDelegate
        self.handler = handler
        super.init()
    }

    // remove in order for puttshack to test
//    override func responds(to aSelector: Selector!) -> Bool {
//        if super.responds(to: aSelector) {
//            return true
//        } else if let originalDelegate = originalDelegate, originalDelegate.responds(to: aSelector) {
//            return true
//        }
//        return false
//    }

    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        if super.responds(to: aSelector) {
            return self
        } else if let originalDelegate = originalDelegate, originalDelegate.responds(to: aSelector) {
            return originalDelegate
        }
        return nil
    }

    /// Checks if the delegate responds to a given selector and determines its conformance to a specific type.
    ///
    /// This method verifies if either the `originalDelegate` or the `session`'s delegate responds to a specified selector.
    /// It accounts for various scenarios to ensure there is no infinite recursion or conflicts caused by swizzling.
    ///
    /// - Parameters:
    ///   - selector: The selector to check for response in the delegate.
    ///   - session: The `URLSession` whose delegate is being examined.
    ///
    /// - Returns: A `DelegateRespondsResult<T>` enum indicating the response status.
    ///   * `.respondsAndConforms(as:)`: The delegate responds to the selector and conforms to the specified type `T`.
    ///   - `.respondsWithoutConformance(object:)`: The delegate responds to the selector but does not conform to the specified type `T`.
    ///   - `.doesNotRespond`: Neither the `originalDelegate` nor the `session.delegate` respond to the selector, or a recursion guard was triggered.
    ///
    /// - Note:
    ///   - The method prevents infinite recursion by guarding against cases where the `session.delegate` is the current instance (`self`).
    ///   - It ensures that delegates already swizzled by other frameworks are not re-invoked, avoiding potential conflicts.
    private func checkIfDelegateResponds<T: URLSessionDelegate>(
        toSelector selector: Selector,
        session: URLSession
    ) -> DelegateRespondsResult<T> {

        // check if the originalDelegate responds to the selector
        if let originalDelegate = originalDelegate,
            originalDelegate.responds(to: selector) {
            if let delegateAsT = originalDelegate as? T {
                return .respondsAndConforms(as: delegateAsT)
            } else if let object = originalDelegate as? NSObject {
                return .respondsWithoutConformance(object: object)
            }
        }

        // guard that we are not the session.delegate to prevent infinite recursion
        guard (session.delegate as? URLSessionDelegateProxy) != self else {
            return .doesNotRespond
        }

        // avoid forwarding the delegate if it was already swizzled by somebody else
        // during our swizzling to prevent potential infinite recursion.
        guard self.swizzledDelegate == nil else {
            return .doesNotRespond
        }

        // if session delegate also responds to selector, we must call it
        if let sessionDelegate = session.delegate,
           sessionDelegate.responds(to: selector) {
            if let sessionDelegateAsT = sessionDelegate as? T {
                return .respondsAndConforms(as: sessionDelegateAsT)
            } else if let object = sessionDelegate as? NSObject {
                return .respondsWithoutConformance(object: object)
            }
        }

        // If no case applies
        return .doesNotRespond
    }
}

// MARK: - Definition of DelegateRespondsResult
fileprivate extension URLSessionDelegateProxy {
    enum DelegateRespondsResult<T> {
        /// The delegate responds to the selector and can be cast to T
        case respondsAndConforms(as: T)

        /// The delegate responds to the selector but cannot be cast to T
        case respondsWithoutConformance(object: NSObject)

        /// The delegate does not respond to the selector or it doesn't apply
        case doesNotRespond
    }
}

extension URLSessionDelegateProxy: URLSessionDelegate {
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        let selector = #selector(
            URLSessionDelegate.urlSession(_:didBecomeInvalidWithError:)
        )

        let responds: DelegateRespondsResult<URLSessionDelegate> = checkIfDelegateResponds(
            toSelector: selector,
            session: session
        )

        switch responds {
        case .respondsAndConforms(let delegate):
            delegate.urlSession?(session, didBecomeInvalidWithError: error)
        case .respondsWithoutConformance(let object):
            EMBURLSessionDelegateForwarder().forward(
                to: object,
                urlSession: session,
                didBecomeInvalidWithError: error
            )
        case .doesNotRespond:
            break
        }

        originalDelegate = nil
    }
}

// MARK: - URLSessionDataDelegate conformance
extension URLSessionDelegateProxy: URLSessionDataDelegate {
    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive data: Data) {
        let selector = #selector(
            URLSessionDataDelegate.urlSession(_:dataTask:didReceive:)
        )

        if var previousData = dataTask.embraceData {
            previousData.append(data)
            dataTask.embraceData = previousData
        } else {
            dataTask.embraceData = data
        }

        let responds: DelegateRespondsResult<URLSessionDataDelegate> = checkIfDelegateResponds(
            toSelector: selector,
            session: session
        )

        switch responds {
        case .respondsAndConforms(let delegate):
            delegate.urlSession?(session, dataTask: dataTask, didReceive: data)
        case .respondsWithoutConformance(let object):
            EMBURLSessionDelegateForwarder().forward(
                to: object,
                urlSession: session,
                dataTask: dataTask,
                didReceive: data
            )
        case .doesNotRespond:
            break
        }
    }
}

// MARK: - URLSessionTaskDelegate conformance
extension URLSessionDelegateProxy: URLSessionTaskDelegate {
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didFinishCollecting metrics: URLSessionTaskMetrics) {
        handler.finish(task: task, data: nil, error: nil)

        let selector = #selector(
            URLSessionTaskDelegate.urlSession(_:task:didFinishCollecting:)
        )

        let responds: DelegateRespondsResult<URLSessionTaskDelegate> = checkIfDelegateResponds(
            toSelector: selector,
            session: session
        )

        switch responds {
        case .respondsAndConforms(let delegate):
            delegate.urlSession?(session, task: task, didFinishCollecting: metrics)
        case .respondsWithoutConformance(let object):
            EMBURLSessionDelegateForwarder().forward(
                to: object,
                urlSession: session,
                task: task,
                didFinishCollectiongMetrics: metrics
            )
        case .doesNotRespond:
            break
        }
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        handler.finish(task: task, data: nil, error: error)
        let selector = #selector(
            URLSessionTaskDelegate.urlSession(_:task:didCompleteWithError:)
        )

        let responds: DelegateRespondsResult<URLSessionTaskDelegate> = checkIfDelegateResponds(
            toSelector: selector,
            session: session
        )

        switch responds {
        case .respondsAndConforms(let delegate):
            delegate.urlSession?(session, task: task, didCompleteWithError: error)
        case .respondsWithoutConformance(let object):
            EMBURLSessionDelegateForwarder().forward(
                to: object,
                urlSession: session,
                task: task,
                didCompleteWithError: error
            )
        case .doesNotRespond:
            break
        }
    }
}

// MARK: - URLSessionDownloadDelegate conformance
extension URLSessionDelegateProxy: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        let selector = #selector(
            URLSessionDownloadDelegate.urlSession(_:downloadTask:didFinishDownloadingTo:)
        )

        let responds: DelegateRespondsResult<URLSessionDownloadDelegate> = checkIfDelegateResponds(
            toSelector: selector,
            session: session
        )

        switch responds {
        case .respondsAndConforms(let delegate):
            delegate.urlSession(session, downloadTask: downloadTask, didFinishDownloadingTo: location)
        case .respondsWithoutConformance(let object):
            EMBURLSessionDelegateForwarder().forward(
                to: object,
                urlSession: session,
                downloadTask: downloadTask,
                didFinishDownloadingTo: location
            )
        case .doesNotRespond:
            break
        }
    }
}

// MARK: - URLSessionStreamDelegate conformance
extension URLSessionDelegateProxy: URLSessionStreamDelegate {}
