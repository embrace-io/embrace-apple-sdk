//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceCore

class UIWindowSendEventSwizzlerTests: XCTestCase {
    private var sut: UIWindowSendEventSwizzler!
    private var handler: MockTapCaptureServiceHandler!
    private var event: UIEvent!

    override func tearDownWithError() throws {
        try? sut.unswizzleInstanceMethod()
    }

    func testAfterInstall_onSendingTapEventToWindow_handlerShouldCaptureEvent() throws {
        givenUIWindowSendEventSwizzler()
        try givenSwizzlingWasDone()
        whenSendingATapEventToWindow()
        thenHandlerShouldHaveCapturedTapEvent()
    }

    func testWithoutInstall_onSendingTapEventToWindow_handlerShouldntCaptureEvent() {
        givenUIWindowSendEventSwizzler()
        whenSendingATapEventToWindow()
        thenHandlerShouldntHaveCapturedTapEvent()
    }
}

private extension UIWindowSendEventSwizzlerTests {
    func givenUIWindowSendEventSwizzler() {
        handler = .init()
        sut = .init(handler: handler)
    }

    func givenSwizzlingWasDone() throws {
        try sut.install()
    }

    func whenSendingATapEventToWindow() {
        event = MockTapEvent(mockedTouches: [.init()])
        UIWindow().sendEvent(event)
    }

    func thenHandlerShouldHaveCapturedTapEvent() {
        XCTAssertTrue(handler.didCallHandlerCapturedEvent)
        XCTAssertEqual(handler.handleCapturedEventParameter, event)
    }

    func thenHandlerShouldntHaveCapturedTapEvent() {
        XCTAssertFalse(handler.didCallHandlerCapturedEvent)
    }
}
