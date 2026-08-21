//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceConfiguration
import EmbraceSemantics
import OpenTelemetryApi
import TestSupport
import XCTest

@testable import EmbraceCore
@testable import EmbraceOTelInternal
@testable import EmbraceStorageInternal
@testable import OpenTelemetrySdk

/// Covers the live session span, which is what a customer's own span processor observes.
/// The session *payload* is covered by `SessionPayloadBuilderTests`, and needs a separate path because
/// `SessionSpanUtils.payload` rebuilds the attribute list from the session record rather than the span.
final class ExperimentsSessionSpanTests: XCTestCase {

    var storage: EmbraceStorage!
    var controller: SessionController!
    var handler: ExperimentsHandler!
    var spanProcessor: MockSpanProcessor!
    var stateProvider: MockEmbraceSDKStateProvider!

    override func setUpWithError() throws {
        // a real tracer provider, so the session span records attributes
        spanProcessor = MockSpanProcessor()
        EmbraceOTel.setup(spanProcessors: [spanProcessor])

        storage = try EmbraceStorage.createInMemoryDb()
        controller = SessionController(storage: storage, upload: nil, config: nil)
        stateProvider = MockEmbraceSDKStateProvider()
        controller.sdkStateProvider = stateProvider
        handler = ExperimentsHandler(
            storage: storage,
            experimentsLimits: ExperimentsLimits(),
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
        handler = nil
        storage.coreData.destroy()
        storage = nil
    }

    /// Reads the attribute off the live session span, which is what a custom span processor sees.
    private func sessionSpanAttribute() -> String? {
        guard let span = controller.currentSessionSpan as? ReadableSpan else {
            XCTFail("the session span should be a recording span")
            return nil
        }
        return span.toSpanData().attributes[SpanSemantics.keyExperiments]?.description
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

        XCTAssertNotNil(controller.currentSessionSpan as? ReadableSpan, "guards against a vacuous pass")
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
}
