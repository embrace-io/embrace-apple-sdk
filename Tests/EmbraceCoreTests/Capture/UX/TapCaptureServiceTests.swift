//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)
import XCTest
import UIKit
@testable import EmbraceCore
import EmbraceOTelInternal
import TestSupport

// swiftlint:disable force_cast

final class TapCaptureServiceTests: XCTestCase {

    private var otel: MockEmbraceOpenTelemetry!

    override func setUpWithError() throws {
        otel = MockEmbraceOpenTelemetry()
    }

    override func tearDownWithError() throws {
        otel = nil
    }

    func test_tap() throws {
        // given an installed and started tap capture service
        let service = TapCaptureService()
        service.install(otel: otel)
        service.start()

        // when a tap is done
        let event = MockTapEvent(mockedTouches: [MockUITouch(touchedView: UIView())])
        UIWindow().sendEvent(event)

        // then the tap is captured
        XCTAssertEqual(otel.events.count, 1)
        XCTAssertEqual(otel.events[0].name, TapCaptureService.Constants.eventName)
    }

    func test_tap_notStarted() throws {
        // given an installed but not started tap capture service
        let service = TapCaptureService()

        // when a tap is done
        let event = MockTapEvent(mockedTouches: [.init()])
        UIWindow().sendEvent(event)

        // then the tap is not captured
        XCTAssertEqual(otel.events.count, 0)
    }

    func test_tap_stopped() throws {
        // given an installed but stopped tap capture service
        let service = TapCaptureService()
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
        try assertViewName(view: view, viewName: "an_identifier")
    }

    func test_tap_eventName_noAccessibilityIdentifier() throws {
        let view = UIView()
        try assertViewName(view: view, viewName: "UIView")
    }

    func test_tap_eventName_keyboardLayout() throws {
        try assertNoCoordinate(viewName: "UIKeyboardLayout")
    }

    func test_tap_eventName_remoteKeyboardWindow() throws {
        try assertNoCoordinate(viewName: "UIRemoteKeyboardWindow")
    }

    func test_ignoredViewTypes() throws {
        // given a capture service with an ignore list
        let options = TapCaptureService.Options(ignoredViewTypes: [MockView.self])
        let service = TapCaptureService(options: options)
        service.install(otel: otel)
        service.start()

        // when a tap is done on a view that should be ignored
        let tap = MockTapEvent(mockedTouches: [MockUITouch(touchedView: MockView())])
        UIWindow().sendEvent(tap)

        // then the tap is not captured
        XCTAssertEqual(otel.events.count, 0)
    }

    func test_captureCoordinatesDsiabled() throws {
        // given a capture service with coordinates capture disabled
        let options = TapCaptureService.Options(captureTapCoordinates: false)
        let service = TapCaptureService(options: options)
        service.install(otel: otel)
        service.start()

        // when a tap is done on a view that should be ignored
        let tap = MockTapEvent(mockedTouches: [MockUITouch(touchedView: UIView())])
        UIWindow().sendEvent(tap)

        // then the tap is not captured without coordinates
        XCTAssertEqual(otel.events.count, 1)
        XCTAssertNil(otel.events[0].attributes[TapCaptureService.Constants.tapCoordinates])
    }

    func test_delegate() throws {
        // given a capture service with a delegate
        let delegate = MockTapCaptureserviceDelegate()
        let options = TapCaptureService.Options(delegate: delegate)
        let service = TapCaptureService(options: options)
        service.install(otel: otel)
        service.start()

        // when taps are done
        delegate.shouldCaptureNextTap = false
        let tap1 = MockTapEvent(mockedTouches: [MockUITouch(touchedView: UIView())])
        UIWindow().sendEvent(tap1)

        delegate.shouldCaptureNextTap = true
        delegate.shouldCaptureNextCoordinates = false
        let tap2 = MockTapEvent(mockedTouches: [MockUITouch(touchedView: UIView())])
        UIWindow().sendEvent(tap2)

        delegate.shouldCaptureNextTap = true
        delegate.shouldCaptureNextCoordinates = true
        let tap3 = MockTapEvent(mockedTouches: [MockUITouch(touchedView: MockView())])
        UIWindow().sendEvent(tap3)

        // then the taps are captured correctly
        XCTAssertEqual(otel.events.count, 2)
        XCTAssertNil(otel.events[0].attributes[TapCaptureService.Constants.tapCoordinates])
        XCTAssertNotNil(otel.events[1].attributes[TapCaptureService.Constants.tapCoordinates])
    }

    func assertViewName(view: UIView, viewName: String) throws {
        // given an installed and started tap capture service
        let service = TapCaptureService()
        service.install(otel: otel)
        service.start()

        // when a tap is done on a view
        let tap = MockTapEvent(mockedTouches: [MockUITouch(touchedView: view)])
        UIWindow().sendEvent(tap)

        // then the tap is captured with the correct view name
        XCTAssertEqual(otel.events.count, 1)
        let event = try XCTUnwrap(otel.events.first)

        XCTAssertEqual(event.attributes[TapCaptureService.Constants.viewName], .string(viewName))
        XCTAssertNotNil(event.attributes[TapCaptureService.Constants.tapCoordinates])
    }

    func assertNoCoordinate(viewName: String) throws {
        // given an installed and started tap capture service
        let service = TapCaptureService()
        service.install(otel: otel)
        service.start()

        // when a tap is done on a view that shouldn't track coordinates
        let objectType = try XCTUnwrap(NSClassFromString(viewName) as? NSObject.Type)
        let view = objectType.init() as! UIView
        let tap = MockTapEvent(mockedTouches: [MockUITouch(touchedView: view)])
        UIWindow().sendEvent(tap)

        // then the tap is captured without coordinates
        XCTAssertEqual(otel.events.count, 1)
        let event = try XCTUnwrap(otel.events.first)

        XCTAssertEqual(event.attributes[TapCaptureService.Constants.viewName], .string(viewName))
        XCTAssertEqual(event.attributes["emb.type"], .string(TapCaptureService.Constants.eventType))
        XCTAssertNil(event.attributes[TapCaptureService.Constants.tapCoordinates])
    }
}

class MockView: UIView {

}

class MockTapCaptureserviceDelegate: NSObject, TapCaptureServiceDelegate {

    var shouldCaptureNextTap: Bool = true
    func shouldCaptureTap(onView: UIView) -> Bool {
        return shouldCaptureNextTap
    }
    
    var shouldCaptureNextCoordinates: Bool = true
    func shouldCaptureTapCoordinates(onView: UIView) -> Bool {
        return shouldCaptureNextCoordinates
    }
}

// swiftlint:enable force_cast

#endif
