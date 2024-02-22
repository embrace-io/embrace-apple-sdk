//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(UIKit)
import XCTest

@testable import EmbraceOTel
import EmbraceStorage
import EmbraceCommon

@testable import EmbraceCore

class DefaultTapCaptureServiceHandlerTests: XCTestCase {
    private var sut: DefaultTapCaptureServiceHandler!
    private var lock = UnfairLock()
    private var embrace: Embrace!

    override func setUpWithError() throws {
        embrace = try embraceInstance()
    }

    override func tearDownWithError() throws {
        _ = try embrace.storage.dbQueue.inDatabase { db in
            try SpanRecord.deleteAll(db)
        }
        try embrace.storage.dbQueue.close()
    }

    // MARK: - State Change Tests

    func test_HandlerDefaultStateIsInitialized() throws {
        sut = .init(client: embrace)
        XCTAssertEqual(sut.state, .initialized)
    }

    func test_OnChangeStateToPaused_StateShouldChangeToPaused() throws {
        try givenTapCaptureService(withInitialState: .initialized)
        whenInvokingOnChangeState(withNewState: .paused)
        thenTapCaptureServiceState(is: .paused)
    }

    func test_OnChangeStateToUninstalled_StateShouldChangeToPaused() throws {
        try givenTapCaptureService(withInitialState: .initialized)
        whenInvokingOnChangeState(withNewState: .uninstalled)
        thenTapCaptureServiceState(is: .paused)
    }

    func test_OnChangeStateToListening_StateShouldChangeToListening() throws {
        try givenTapCaptureService(withInitialState: .initialized)
        whenInvokingOnChangeState(withNewState: .listening)
        thenTapCaptureServiceState(is: .listening)
    }

    // MARK: - Event Handling Tests
    func test_onHandleCaptureEventWithTapEvent_shouldAddItToSession() throws {
        try givenTapCaptureService(withInitialState: .listening)
        whenInvokingHandleCapturedEventWithTapEvent()
        try thenEventShouldBeAddedToSessionSpan()
    }

    func test_onHandleCaptureEventWithTapEventOnViewWithAccessibility_shouldIncludeItToSessionSpanEvent() throws {
        try givenTapCaptureService(withInitialState: .listening)
        let view = UIView()
        view.accessibilityIdentifier = "an_identifier"
        whenInvokingHandleCapturedEventWithTapEvent(inView: view)
        try thenRecordedEventViewNameShouldBe("an_identifier")
    }

    func test_onHandleCaptureEventWithTapEventOnViewWithoutAccessibility_shouldAddClassNameToSessionSpanEvent() throws {
        try givenTapCaptureService(withInitialState: .listening)
        let view = UIView()
        whenInvokingHandleCapturedEventWithTapEvent(inView: view)
        try thenRecordedEventViewNameShouldBe("UIView")
    }

    func test_onHandleCaptureEventWithTapEventInKeyboardLayout_shouldRecordAtPointZeroZero() throws {
        try givenTapCaptureService(withInitialState: .listening)
        let view = try createKeyboardLayoutView(withClassName: "UIKeyboardLayout")
        whenInvokingHandleCapturedEventWithTapEvent(inView: view)
        try thenRecordedCoordinatesShouldBe("0.0,0.0")
    }

    func test_onHandleCaptureEventWithTapEventInRemoteKeyboardLayout_shouldRecordAtPointZeroZero() throws {
        try givenTapCaptureService(withInitialState: .listening)
        let view = try createKeyboardLayoutView(withClassName: "UIRemoteKeyboardWindow")
        whenInvokingHandleCapturedEventWithTapEvent(inView: view)
        try thenRecordedCoordinatesShouldBe("0.0,0.0")
    }

    func testNonListeningHandler_onHandleCaptureEventWithTapEvent_shouldntAddItToSession() throws {
        let nonListeningStates: [CaptureServiceHandlerState] = [.initialized, .paused]
        let nonListeningState = try XCTUnwrap(nonListeningStates.randomElement())
        try givenTapCaptureService(withInitialState: nonListeningState)
        whenInvokingHandleCapturedEventWithTapEvent()
        try thenEventShouldntBeAddedToSessionSpan()
    }
}

// MARK: - Helper Methods
private extension DefaultTapCaptureServiceHandlerTests {
    func embraceInstance() throws -> Embrace {
        return try lock.locked {
            try Embrace.setup(options: .init(appId: "tapsT",
                                             appGroupId: nil,
                                             captureServices: []))
            XCTAssertNotNil(Embrace.client)
            let embrace = try XCTUnwrap(Embrace.client)
            try embrace.start()
            wait(timeout: 1.0, until: { embrace.currentSessionId() != nil })
            Embrace.client = nil
            return embrace
        }
    }

    func givenTapCaptureService(withInitialState initialState: CaptureServiceHandlerState) throws {
        sut = .init(initialState: initialState, client: embrace)
    }

    func whenInvokingOnChangeState(withNewState state: CaptureServiceState) {
        sut.changedState(to: state)
    }

    func whenInvokingHandleCapturedEventWithTapEvent(inView view: UIView = UIView()) {
        sut.handleCapturedEvent(MockTapEvent(mockedTouches: [MockUITouch(touchedView: view)]))
    }

    func thenTapCaptureServiceState(is state: CaptureServiceHandlerState) {
        XCTAssertEqual(sut.state, state)
    }

    func thenEventShouldBeAddedToSessionSpan() throws {
        let recordingSpan = try XCTUnwrap(embrace.sessionController.currentSessionSpan as? ReadableSpan)
        let recordedEvent = try XCTUnwrap(recordingSpan.toSpanData().events.first)
        XCTAssertEqual(recordedEvent.name, "action.tap")
    }

    func thenEventShouldntBeAddedToSessionSpan() throws {
        let recordingSpan = try XCTUnwrap(embrace.sessionController.currentSessionSpan as? ReadableSpan)
        XCTAssertEqual(recordingSpan.toSpanData().events.count, 0)
    }

    func thenRecordedCoordinatesShouldBe(_ stringPoint: String) throws {
        let recordingSpan = try XCTUnwrap(embrace.sessionController.currentSessionSpan as? ReadableSpan)
        let recordedEvent = try XCTUnwrap(recordingSpan.toSpanData().events.first)
        XCTAssertEqual(recordedEvent.attributes["point"], .string(stringPoint))
    }

    func thenRecordedEventViewNameShouldBe(_ viewName: String) throws {
        let recordingSpan = try XCTUnwrap(embrace.sessionController.currentSessionSpan as? ReadableSpan)
        let recordedEvent = try XCTUnwrap(recordingSpan.toSpanData().events.first)
        XCTAssertEqual(recordedEvent.attributes["view_name"], .string(viewName))
    }

    func createKeyboardLayoutView(withClassName className: String) throws -> UIView {
        let objectType = try XCTUnwrap(NSClassFromString(className) as? NSObject.Type)
        let object = objectType.init()
        return try XCTUnwrap(object as? UIView)
    }
}
#endif
