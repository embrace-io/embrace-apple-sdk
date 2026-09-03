//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceConfiguration
import EmbraceSemantics
import EmbraceStorageInternal
import TestSupport
import XCTest

@testable import EmbraceCore

/// Covers the seam between `SessionController` and the state primitive.
///
/// `StateRecorderTests` drives the recorder directly; these tests drive the *controller*, which is
/// where the production behavior actually lives — in particular the ordering that the state span
/// depends on to land inside its part's payload.
final class SessionControllerStateSpansTests: XCTestCase {

    private var storage: EmbraceStorage!
    private var controller: SessionController!
    private var userSessionController: UserSessionController!
    private var configurable: MockEmbraceConfigurable!
    private var otel: MockOTelSignalsHandler!
    private var coordinator: StateCaptureCoordinator!
    private var recorder: StateRecorder<String>!
    private let sdkStateProvider = MockEmbraceSDKStateProvider()

    private let stateName = "screen-automatic"

    override func setUpWithError() throws {
        storage = try EmbraceStorage.createInMemoryDb()
        otel = MockOTelSignalsHandler()

        controller = SessionController(storage: storage, upload: nil, config: nil)
        controller.sdkStateProvider = sdkStateProvider
        controller.otel = otel

        configurable = MockEmbraceConfigurable()
        userSessionController = UserSessionController(storage: storage, config: configurable)
        userSessionController.sessionController = controller
        controller.userSessionController = userSessionController

        coordinator = StateCaptureCoordinator()
        controller.stateCoordinator = coordinator

        recorder = StateRecorder(
            stateName: stateName,
            defaultValue: "Initializing",
            otel: otel
        )
        coordinator.register(recorder, sessionSpan: nil)
    }

    override func tearDownWithError() throws {
        storage.coreData.destroy()
        storage = nil
        controller = nil
        userSessionController = nil
        configurable = nil
        otel = nil
        coordinator = nil
        recorder = nil
    }

    private var stateSpans: [EmbraceSpan] {
        otel.startedSpans.filter { $0.name == SpanSemantics.State.spanName(for: stateName) }
    }

    private var sessionSpans: [EmbraceSpan] {
        otel.startedSpans.filter { $0.name == SpanSemantics.Session.name }
    }

    // MARK: - Part start

    func test_startSession_opensAStateSpanAtThePartStart() throws {
        controller.startSession(state: .foreground)

        XCTAssertEqual(stateSpans.count, 1)
        let stateSpan = try XCTUnwrap(stateSpans.first)
        let sessionSpan = try XCTUnwrap(controller.currentSessionSpan)

        XCTAssertEqual(stateSpan.startTime, sessionSpan.startTime)
        XCTAssertEqual(
            stateSpan.attributes[SpanSemantics.State.keyInitialValue]?.description,
            "Initializing")
        XCTAssertNil(stateSpan.endTime)
    }

    // MARK: - Part end

    func test_endSession_closesTheStateSpanBeforeThePartSpan() throws {
        controller.startSession(state: .foreground)
        let stateSpan = try XCTUnwrap(stateSpans.first)
        let sessionSpan = try XCTUnwrap(controller.currentSessionSpan)

        controller.endSession()

        // Asserted on the order the spans were *closed*, not on their end times: `endSessionNoLock`
        // stamps both from one `now`, so comparing timestamps is `now <= now` and holds however the
        // calls are ordered. Order is the actual invariant — a state span closed after its part
        // misses the part's payload entirely and links from an already-flushed span.
        let ended = otel.endedSpans.map { $0.context.spanId }
        let stateIndex = try XCTUnwrap(ended.firstIndex(of: stateSpan.context.spanId))
        let sessionIndex = try XCTUnwrap(ended.firstIndex(of: sessionSpan.context.spanId))

        XCTAssertLessThan(stateIndex, sessionIndex)
    }

    func test_endSession_linksTheStateSpanFromThePartSpan() throws {
        controller.startSession(state: .foreground)
        let stateSpan = try XCTUnwrap(stateSpans.first)
        let sessionSpan = try XCTUnwrap(controller.currentSessionSpan)

        controller.endSession()

        let link = try XCTUnwrap(sessionSpan.links.first)
        XCTAssertEqual(link.context.spanId, stateSpan.context.spanId)
        XCTAssertEqual(link.attributes[SpanSemantics.keyLinkType]?.description, "STATE")
    }

    // MARK: - Across parts

    func test_consecutiveParts_eachGetTheirOwnStateSpanAndCarryTheValue() throws {
        controller.startSession(state: .foreground)
        recorder.onStateChange(to: "ProductDetail", at: Date())
        controller.endSession()

        controller.startSession(state: .foreground)

        XCTAssertEqual(stateSpans.count, 2, "each part gets its own state span")

        let second = try XCTUnwrap(stateSpans.last)
        XCTAssertEqual(
            second.attributes[SpanSemantics.State.keyInitialValue]?.description,
            "ProductDetail",
            "the value must carry over into the next part")
        XCTAssertNil(second.endTime)

        // Each part span links only its own state span.
        for sessionSpan in sessionSpans where sessionSpan.endTime != nil {
            XCTAssertEqual(sessionSpan.links.count, 1)
        }
    }

    // MARK: - Discarded parts

    func test_sdkDisabled_discardsThePartAndStillClosesTheStateSpan() throws {
        controller.startSession(state: .foreground)
        let stateSpan = try XCTUnwrap(stateSpans.first)

        // The SDK being disabled makes `endSessionNoLock` delete the part instead of ending it.
        sdkStateProvider.isEnabled = false
        controller.endSession()

        XCTAssertNotNil(stateSpan.endTime, "a discarded part must not leave its state span open")
    }

    func test_afterADiscardedPart_theNextPartStillOpensItsOwnStateSpan() throws {
        controller.startSession(state: .foreground)

        sdkStateProvider.isEnabled = false
        controller.endSession()

        // Regression guard: a token left behind by the discarded part used to make the next part
        // reuse the discarded span instead of opening its own.
        sdkStateProvider.isEnabled = true
        controller.startSession(state: .foreground)

        XCTAssertEqual(stateSpans.count, 2)
        XCTAssertNil(stateSpans.last?.endTime, "state capture must resume on the next part")
    }
}
