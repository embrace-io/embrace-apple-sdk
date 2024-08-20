//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal
import XCTest

class DummyURLSessionInitWithDelegateSwizzler: Swizzlable {
    typealias ImplementationType = @convention(c) (URLSession, Selector, URLSessionConfiguration, URLSessionDelegate?, OperationQueue?) -> URLSession
    typealias BlockImplementationType = @convention(block) (URLSession, URLSessionConfiguration, URLSessionDelegate?, OperationQueue?) -> URLSession
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
        weak var originalDelegate: URLSessionDelegate?
        var didForwardToTargetSuccesfully: Bool = false
        var didInvokeForwardingTarget: Bool = false
        var didInvokeRespondsTo: Bool = false
        var didForwardRespondsToSuccessfullyBool = false

        init(originalDelegate: URLSessionDelegate?) {
            self.originalDelegate = originalDelegate
            super.init()
        }

        override func responds(to aSelector: Selector!) -> Bool {
            didInvokeRespondsTo = true
            if super.responds(to: aSelector) {
                didForwardToTargetSuccesfully = true
                return true
            } else if let originalDelegate = originalDelegate, originalDelegate.responds(to: aSelector) {
                didForwardToTargetSuccesfully = true
                return true
            }
            return false
        }

        override func forwardingTarget(for aSelector: Selector!) -> Any? {
            didInvokeForwardingTarget = true
            if super.responds(to: aSelector) {
                didForwardToTargetSuccesfully = true
                return self
            } else if let originalDelegate = originalDelegate, originalDelegate.responds(to: aSelector) {
                didForwardToTargetSuccesfully = true
                return originalDelegate
            }
            return nil
        }
    }
}
