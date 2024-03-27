//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)
import XCTest
import UIKit
@testable import EmbraceCore
import EmbraceOTel
import TestSupport

// swiftlint:disable force_cast

final class TapCaptureServiceTests: XCTestCase {

    private var service: TapCaptureService!
    private var otel: MockEmbraceOpenTelemetry!

    override func setUpWithError() throws {
        otel = MockEmbraceOpenTelemetry()
        service = TapCaptureService()
    }

    override func tearDownWithError() throws {
        service = nil
        otel = nil
    }

    func test_tap() throws {
        // given an installed and started tap capture service
        service.install(otel: otel)
        service.start()

        // when a tap is done
        let event = MockTapEvent(mockedTouches: [MockUITouch(touchedView: UIView())])
        UIWindow().sendEvent(event)

        // then the tap is captured
        XCTAssertEqual(otel.events.count, 1)
        XCTAssertEqual(otel.events[0].name, "action.tap")
    }

    func test_tap_uninstalled() throws {
        // given an instantiated but uninstalled tap capture service

        // when a tap is done
        let event = MockTapEvent(mockedTouches: [.init()])
        UIWindow().sendEvent(event)

        // then the tap is not captured
        XCTAssertEqual(otel.events.count, 0)
    }

    func test_tap_notStarted() throws {
        // given an installed but not started tap capture service
        service.install(otel: otel)

        // when a tap is done
        let event = MockTapEvent(mockedTouches: [.init()])
        UIWindow().sendEvent(event)

        // then the tap is not captured
        XCTAssertEqual(otel.events.count, 0)
    }

    func test_tap_stopped() throws {
        // given an installed but stopped tap capture service
        service.install(otel: otel)
        service.start()
        service.stop()

        // when a tap is done
        let event = MockTapEvent(mockedTouches: [.init()])
        UIWindow().sendEvent(event)

        // then the tap is not captured
        XCTAssertEqual(otel.events.count, 0)
    }

    func test_tap_eventName_accessibilityIdentifier() throws {
        let view = UIView()
        view.accessibilityIdentifier = "an_identifier"
        try testViewName(view: view, viewName: "an_identifier")
    }

    func test_tap_eventName_noAccessibilityIdentifier() throws {
        let view = UIView()
        try testViewName(view: view, viewName: "UIView")
    }

    func test_tap_eventName_keyboardLayout() throws {
        try testNoCoordinate(viewName: "UIKeyboardLayout")
    }

    func test_tap_eventName_remoteKeyboardWindow() throws {
        try testNoCoordinate(viewName: "UIRemoteKeyboardWindow")
    }

    func testViewName(view: UIView, viewName: String) throws {
        // given an installed and started tap capture service
        service.install(otel: otel)
        service.start()

        // when a tap is done on a view
        let event = MockTapEvent(mockedTouches: [MockUITouch(touchedView: view)])
        UIWindow().sendEvent(event)

        // then the tap is captured with the correct view name
        XCTAssertEqual(otel.events.count, 1)
        XCTAssertEqual(otel.events[0].attributes["view_name"], .string(viewName))
    }

    func testNoCoordinate(viewName: String) throws {
        // given an installed and started tap capture service
        service.install(otel: otel)
        service.start()

        // when a tap is done on a view that shouldn't track coordinates
        let objectType = try XCTUnwrap(NSClassFromString(viewName) as? NSObject.Type)
        let view = objectType.init() as! UIView
        let event = MockTapEvent(mockedTouches: [MockUITouch(touchedView: view)])
        UIWindow().sendEvent(event)

        // then the tap is captured without coordinates
        XCTAssertEqual(otel.events.count, 1)
        XCTAssertEqual(otel.events[0].attributes["view_name"], .string(viewName))
        XCTAssertEqual(otel.events[0].attributes["point"], .string("0.0,0.0"))
    }
}

// swiftlint:enable force_cast

#endif
