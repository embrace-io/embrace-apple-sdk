//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

class EmbraceDummyURLSessionDelegate: NSObject, URLSessionDelegate {}

class URLSessionDelegateProxy: NSObject {
    var originalDelegate: URLSessionDelegate?

    /// This helps to determine if, during the creation of the `URLSessionDelegateProxy`,
    /// another player or SDK has already swizzled or proxied NSURLSession/URLSession.
    weak var swizzledDelegate: URLSessionDelegate?
    let handler: URLSessionTaskHandler

    init(originalDelegate: URLSessionDelegate?, handler: URLSessionTaskHandler) {
        self.originalDelegate = originalDelegate
        self.handler = handler
        super.init()
    }

    override func responds(to aSelector: Selector!) -> Bool {
        if super.responds(to: aSelector) {
            return true
        } else if let originalDelegate = originalDelegate, originalDelegate.responds(to: aSelector) {
            return true
        }
        return false
    }

    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        if super.responds(to: aSelector) {
            return self
        } else if let originalDelegate = originalDelegate, originalDelegate.responds(to: aSelector) {
            return originalDelegate
        }
        return nil
    }

    func originalDelegateResponds(to aSelector: Selector) -> Bool {
        if let delegate = originalDelegate {
            return delegate.responds(to: aSelector)
        }
        return false
    }

    /// Performs logic to call `originalDelegate` and the `session.delegate` when necessary. Will call `block` 0 or 1 time
    /// Will call  block with`originalDelegate` if non-nil and responds to selector
    /// If we did not call `originalDelegate` then call block with `session.delegate` if non-nil and responds to selector
    /// - Note Will also prevent infinite recursion by checking that current invocation is not already against session.delegate
    func invokeDelegates<T: URLSessionDelegate>(session: URLSession, selector: Selector, block: (T) -> Void) {
        // call original delegate
        if let delegate = originalDelegate as? T, delegate.responds(to: selector) {
            block(delegate)
            return
        }

        guard (session.delegate as? URLSessionDelegateProxy) != self else {
            // guard that we are not the session.delegate to prevent infinite recursion
            return
        }

        // Avoid forwarding the delegate if it was already swizzled by somebody else
        // during our swizzling to prevent potential infinite recursion.
        guard self.swizzledDelegate == nil else {
            return
        }

        // if session delegate also responds to selector, we must call it
        if let sessionDelegate = session.delegate as? T,
            sessionDelegate.responds(to: selector) {

            block(sessionDelegate)
        }
    }

    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        let selector = #selector(
            URLSessionDelegate.urlSession(_:didBecomeInvalidWithError:)
        )
        // If the `originalDelegate` has implemented the `didBecomeInvalidWithError` we forward them the call to them.
        // However, to prevent any kind of leakage, we clean on end the `originalDelegate` so we don't retain it.
        invokeDelegates(session: session, selector: selector) { (delegate: URLSessionDelegate) in
            delegate.urlSession?(session, didBecomeInvalidWithError: error)
        }
        originalDelegate = nil
    }

    // Check if this is necessary
    override var description: String {
        return originalDelegate?.description ?? String(describing: type(of: self))
    }
}
