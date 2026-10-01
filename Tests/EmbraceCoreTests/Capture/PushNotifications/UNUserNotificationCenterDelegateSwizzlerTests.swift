//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import UserNotifications
import XCTest

@testable import EmbraceCore

class UNUserNotificationCenterDelegateSwizzlerTests: SwizzlerTestCase {

    let willPresentSelector = #selector(
        UNUserNotificationCenterDelegate.userNotificationCenter(_:willPresent:withCompletionHandler:)
    )

    var proxy: UNUserNotificationCenterDelegateProxy!
    var center: FakeNotificationCenter!

    override func setUpWithError() throws {
        try super.setUpWithError()

        // `UNUserNotificationCenter.current()` is not available in unit tests, so the swizzlers
        // are installed on a fake class exposing the same `delegate` property.
        proxy = UNUserNotificationCenterDelegateProxy(captureData: false)
        center = FakeNotificationCenter()

        try UNUserNotificationCenterSetDelegateSwizzler(proxy: proxy, baseClass: FakeNotificationCenter.self).install()
        try UNUserNotificationCenterGetDelegateSwizzler(proxy: proxy, baseClass: FakeNotificationCenter.self).install()
    }

    override func tearDownWithError() throws {
        restoreSwizzleCacheAdditions()
        try super.tearDownWithError()
    }

    func test_setDelegate_installsProxy() {
        // when setting a delegate
        let appDelegate = MockNotificationCenterDelegate()
        center.delegate = appDelegate

        // then the proxy is installed and forwards to the delegate
        XCTAssert(center.storedDelegate === proxy)
        XCTAssert(proxy.originalDelegate === appDelegate)
    }

    func test_getDelegate_hidesProxy() {
        // given a delegate
        let appDelegate = MockNotificationCenterDelegate()
        center.delegate = appDelegate

        // then the getter returns the delegate, not the proxy
        XCTAssert(center.delegate === appDelegate)
    }

    func test_reassigningCurrentDelegate_keepsOriginalDelegate() {
        // given a delegate
        let appDelegate = MockNotificationCenterDelegate()
        center.delegate = appDelegate

        // when re-assigning the current delegate
        center.delegate = center.delegate

        // then the proxy still forwards to the delegate and doesn't recurse
        XCTAssert(center.storedDelegate === proxy)
        XCTAssert(proxy.originalDelegate === appDelegate)
        XCTAssertTrue(proxy.responds(to: willPresentSelector))
    }

    func test_settingProxy_keepsOriginalDelegate() {
        // given a delegate
        let appDelegate = MockNotificationCenterDelegate()
        center.delegate = appDelegate

        // when setting the proxy itself
        center.delegate = proxy

        // then the proxy doesn't become its own original delegate
        XCTAssert(proxy.originalDelegate === appDelegate)
        XCTAssertTrue(proxy.responds(to: willPresentSelector))
    }

    func test_wrappingCurrentDelegate_doesNotCycle() {
        // given a delegate
        let appDelegate = MockNotificationCenterDelegate()
        center.delegate = appDelegate

        // when another component wraps the current delegate
        let wrapper = ForwardingNotificationCenterDelegate(forwardingTo: center.delegate)
        center.delegate = wrapper

        // then the chain is proxy -> wrapper -> delegate
        XCTAssert(center.storedDelegate === proxy)
        XCTAssert(proxy.originalDelegate === wrapper)
        XCTAssert(wrapper.forwardee === appDelegate)
        XCTAssertTrue(proxy.responds(to: willPresentSelector))
    }

    func test_settingNilDelegate() {
        // given a delegate
        let appDelegate = MockNotificationCenterDelegate()
        center.delegate = appDelegate

        // when setting a nil delegate
        center.delegate = nil

        // then the proxy stays installed without an original delegate
        XCTAssert(center.storedDelegate === proxy)
        XCTAssertNil(proxy.originalDelegate)
        XCTAssertNil(center.delegate)
        XCTAssertFalse(proxy.responds(to: willPresentSelector))
    }
}

/// Mimics the `delegate` property of `UNUserNotificationCenter`.
class FakeNotificationCenter: NSObject {
    @objc dynamic weak var delegate: UNUserNotificationCenterDelegate?

    /// The value actually stored, bypassing any swizzled getter.
    var storedDelegate: UNUserNotificationCenterDelegate? {
        typealias Getter = @convention(c) (AnyObject, Selector) -> UNUserNotificationCenterDelegate?
        let selector = #selector(getter: FakeNotificationCenter.delegate)
        guard let method = class_getInstanceMethod(FakeNotificationCenter.self, selector),
            let original = SwizzleCache.shared.getOriginalMethodImplementation(
                forMethod: method,
                inClass: FakeNotificationCenter.self,
                swizzler: String(describing: UNUserNotificationCenterGetDelegateSwizzler.self)
            )
        else {
            return delegate
        }
        return unsafeBitCast(original, to: Getter.self)(self, selector)
    }
}

class MockNotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([])
    }
}

/// Wraps another delegate and forwards every check and call to it, like delegate-chaining SDKs do.
class ForwardingNotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {
    let forwardee: UNUserNotificationCenterDelegate?

    init(forwardingTo forwardee: UNUserNotificationCenterDelegate?) {
        self.forwardee = forwardee
    }

    override func responds(to aSelector: Selector!) -> Bool {
        super.responds(to: aSelector) || (forwardee?.responds(to: aSelector) ?? false)
    }

    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        forwardee
    }
}
