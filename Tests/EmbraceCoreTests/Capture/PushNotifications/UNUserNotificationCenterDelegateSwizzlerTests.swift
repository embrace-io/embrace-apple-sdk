//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

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
        continueAfterFailure = false

        // `UNUserNotificationCenter.current()` is not available in unit tests, so the swizzler
        // is installed on a fake class exposing the same `delegate` property.
        proxy = UNUserNotificationCenterDelegateProxy(captureData: false)
        center = FakeNotificationCenter()

        try UNUserNotificationCenterSetDelegateSwizzler(proxy: proxy, baseClass: FakeNotificationCenter.self).install()
    }

    override func tearDownWithError() throws {
        restoreSwizzleCacheAdditions()
        try super.tearDownWithError()
    }

    func test_getDelegate_returnsProxy() {
        // given a delegate
        let appDelegate = MockNotificationCenterDelegate()
        center.delegate = appDelegate

        // then the getter returns the proxy, since UIKit delivers callbacks to whatever `delegate` returns
        XCTAssert(center.delegate === proxy)
        XCTAssert(proxy.originalDelegate === appDelegate)
    }

    func test_reassigningCurrentDelegate_keepsOriginalDelegate() {
        // given a delegate
        let appDelegate = MockNotificationCenterDelegate()
        center.delegate = appDelegate

        // when re-assigning the current delegate
        center.delegate = center.delegate

        // then the proxy still forwards to the delegate and doesn't recurse
        XCTAssert(center.delegate === proxy)
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

    func test_settingNilDelegate() {
        // given a delegate
        let appDelegate = MockNotificationCenterDelegate()
        center.delegate = appDelegate

        // when setting a nil delegate
        center.delegate = nil

        // then the proxy stays installed without an original delegate
        XCTAssert(center.delegate === proxy)
        XCTAssertNil(proxy.originalDelegate)
        XCTAssertFalse(proxy.responds(to: willPresentSelector))
    }
}

/// Mimics the `delegate` property of `UNUserNotificationCenter`.
class FakeNotificationCenter: NSObject {
    @objc dynamic weak var delegate: UNUserNotificationCenterDelegate?
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
