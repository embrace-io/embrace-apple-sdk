//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceConfiguration
import EmbraceSemantics
import EmbraceStorageInternal
import TestSupport
import XCTest

@testable import EmbraceCore

/// Covers the live session span, which is what a customer's own span processor observes.
/// The session *payload* is covered by `SessionPayloadBuilderTests`, and needs a separate path because
/// `SessionSpanUtils.payload` rebuilds the attribute list from the session record rather than the span.
final class ExperimentsSessionSpanTests: XCTestCase {

    var storage: EmbraceStorage!
    var otel: MockOTelSignalsHandler!
    var controller: SessionController!
    var userSessionController: UserSessionController!
    var configurable: MockEmbraceConfigurable!
    var handler: ExperimentsHandler!
    // `SessionController` holds this weakly, so the test has to own it.
    let sdkStateProvider = MockEmbraceSDKStateProvider()

    override func setUpWithError() throws {
        storage = try EmbraceStorage.createInMemoryDb()

        otel = MockOTelSignalsHandler()

        controller = SessionController(storage: storage, upload: nil, config: nil)
        controller.sdkStateProvider = sdkStateProvider
        controller.otel = otel

        // Every part-start routes through the user-session controller, and the default mock
        // config keeps back-to-back parts inside the same user session.
        configurable = MockEmbraceConfigurable()
        userSessionController = UserSessionController(storage: storage, config: configurable)
        userSessionController.sessionController = controller
        controller.userSessionController = userSessionController

        handler = ExperimentsHandler(
            storage: storage,
            experimentsLimits: ExperimentsLimits(),
            // The controller observes `Embrace.notificationCenter`, so the handler has to post there.
            configNotificationCenter: Embrace.notificationCenter,
            logger: MockLogger(),
            // These assert the span right after tracking, and the notification that updates it is
            // debounced in production. Reporting inline keeps them about the span, not the timing.
            persistDebounceInterval: 0
        )
        controller.experiments = handler
    }

    override func tearDownWithError() throws {
        controller = nil
        userSessionController = nil
        handler = nil
        otel = nil
        storage.coreData.destroy()
        storage = nil
    }

    /// Reads the attribute off the live session span, which is what a custom span processor sees.
    private func sessionSpanAttribute() -> String? {
        guard let span = controller.currentSessionSpan else {
            XCTFail("there should be a live session span")
            return nil
        }
        return span.attributes[SpanSemantics.keyExperiments]?.description
    }

    func test_sessionStartedAfterTracking_carriesWhatIsAlreadyTracked() {
        handler.trackExperiments([.init(id: "exp", variant: "A", startedAt: Date(timeIntervalSince1970: 1000))])

        controller.startSession(state: .foreground)

        XCTAssertEqual(sessionSpanAttribute(), "e:exp:A:1000000")
    }

    func test_trackingDuringASession_updatesTheSessionSpan() {
        controller.startSession(state: .foreground)
        XCTAssertNil(sessionSpanAttribute())

        handler.trackExperiments([.init(id: "exp", variant: "A", startedAt: Date(timeIntervalSince1970: 1000))])

        XCTAssertEqual(sessionSpanAttribute(), "e:exp:A:1000000")
    }

    func test_untrackingDuringASession_updatesTheSessionSpan() {
        handler.trackExperiments([.init(id: "exp", startedAt: Date(timeIntervalSince1970: 1000))])
        controller.startSession(state: .foreground)

        handler.untrackExperiments(ids: ["exp"], endedAt: Date(timeIntervalSince1970: 2000))

        XCTAssertEqual(sessionSpanAttribute(), "e:exp::1000000:2000000")
    }

    func test_withNothingTracked_theAttributeIsAbsent() {
        controller.startSession(state: .foreground)

        XCTAssertNotNil(controller.currentSessionSpan, "guards against a vacuous pass")
        XCTAssertNil(sessionSpanAttribute())
    }

    /// A new session in the same process starts from the state accumulated so far.
    func test_newSessionInTheSameProcess_carriesTheAccumulatedState() {
        controller.startSession(state: .foreground)
        handler.trackExperiments([.init(id: "exp", startedAt: Date(timeIntervalSince1970: 1000))])

        _ = controller.endSession()
        controller.startSession(state: .foreground)

        XCTAssertEqual(sessionSpanAttribute(), "e:exp::1000000")
    }

    /// The value is exempt from the attribute value length limit, so it must reach the span whole.
    /// Length comes from the number of records, since `id` and `variant` are each capped at 128.
    func test_longValue_isNotTruncatedOnTheSessionSpan() throws {
        let variant = String(repeating: "a", count: 100)
        handler.trackExperiments(
            (0..<20).map {
                .init(id: "exp\($0)", variant: variant, startedAt: Date(timeIntervalSince1970: 1000))
            }
        )

        controller.startSession(state: .foreground)

        let value = try XCTUnwrap(sessionSpanAttribute())
        XCTAssertEqual(value, handler.encodedExperiments)
        XCTAssertGreaterThan(value.count, 1024)
    }
}
