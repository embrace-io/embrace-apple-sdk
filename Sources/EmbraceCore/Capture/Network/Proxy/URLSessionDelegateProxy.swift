//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
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

    // Check if this is necessary
    override var description: String {
        return originalDelegate?.description ?? String(describing: type(of: self))
    }
}
