//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import Foundation
import XCTest

class DummyURLSessionInitWithDelegateSwizzler: Swizzlable {
    typealias ImplementationType =
        @convention(c) (
            URLSession, Selector, URLSessionConfiguration, URLSessionDelegate?, OperationQueue?
        ) -> URLSession
    typealias BlockImplementationType =
        @convention(block) (
            URLSession, URLSessionConfiguration, URLSessionDelegate?, OperationQueue?
        ) -> URLSession
    static var selector: Selector = #selector(
        URLSession.init(configuration:delegate:delegateQueue:)
    )
    var baseClass: AnyClass
    var proxy: DummyURLProxy?

    init(baseClass: AnyClass = URLSession.self) {
        self.baseClass = baseClass
    }

    func install() throws {
        try swizzleClassMethod { originalImplementation -> BlockImplementationType in
            return { [weak self] urlSession, configuration, delegate, queue -> URLSession in
                self?.proxy = DummyURLProxy(originalDelegate: delegate)
                return originalImplementation(urlSession, Self.selector, configuration, self!.proxy, queue)
            }
        }
    }

    class DummyURLProxy: NSObject, URLSessionDelegate {
        var originalDelegate: URLSessionDelegate?
        var didForwardToTargetSuccessfully: Bool = false
        var didInvokeForwardingTarget: Bool = false
        var didInvokeRespondsTo: Bool = false

        init(originalDelegate: URLSessionDelegate?) {
            self.originalDelegate = originalDelegate
            super.init()
        }

        override func responds(to aSelector: Selector!) -> Bool {
            didInvokeRespondsTo = true
            if super.responds(to: aSelector) {
                didForwardToTargetSuccessfully = true
                return true
            } else if let originalDelegate = originalDelegate, originalDelegate.responds(to: aSelector) {
                didForwardToTargetSuccessfully = true
                return true
            }
            return false
        }

        override func forwardingTarget(for aSelector: Selector!) -> Any? {
            didInvokeForwardingTarget = true
            if super.responds(to: aSelector) {
                didForwardToTargetSuccessfully = true
                return self
            } else if let originalDelegate = originalDelegate, originalDelegate.responds(to: aSelector) {
                didForwardToTargetSuccessfully = true
                return originalDelegate
            }
            return nil
        }
    }
}
