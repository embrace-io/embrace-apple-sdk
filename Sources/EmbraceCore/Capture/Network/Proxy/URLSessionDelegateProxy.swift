//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

class EmbraceDummyURLSessionDelegate: NSObject, URLSessionDelegate {}

class URLSessionDelegateProxy: NSObject {
    weak var originalDelegate: URLSessionDelegate?
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

        // if session delegate also responds to selector, we must call it
        if let sessionDelegate = session.delegate as? T,
            sessionDelegate.responds(to: selector) {

            block(sessionDelegate)
        }
    }

    // Check if this is necessary
    override var description: String {
        return originalDelegate?.description ?? String(describing: type(of: self))
    }
}
