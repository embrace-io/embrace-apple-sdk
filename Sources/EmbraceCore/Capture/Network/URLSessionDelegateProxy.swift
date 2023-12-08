//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

class URLSessionDelegateProxy: NSObject {
    weak var originalDelegate: URLSessionDelegate?
    private let handler: URLSessionTaskHandler

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
        // TODO: Check if this should be switched (first the original, then super)
        // Test the case where we don't have implemented a specifc method, the originaldelegate yes,
        // and our superclass also has that implementation. It should call the originalDelegate's one.
        if super.responds(to: aSelector) {
            return self
        } else if let originalDelegate = originalDelegate, originalDelegate.responds(to: aSelector) {
            return originalDelegate
        }
        return nil
    }

    private func doesOriginalDelegateResponds(to aSelector: Selector) -> Bool {
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

// MARK: - URLSessionTaskDelegate related methods
extension URLSessionDelegateProxy: URLSessionTaskDelegate {
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didFinishCollecting metrics: URLSessionTaskMetrics) {
        // Execute our logic
        let selector = #selector(
            URLSessionTaskDelegate.urlSession(_:task:didFinishCollecting:)
        )
        if doesOriginalDelegateResponds(to: selector),
           let taskDelegate = originalDelegate as? URLSessionTaskDelegate {
            taskDelegate.urlSession?(session, task: task, didFinishCollecting: metrics)
        }
    }
}
