//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceSemantics
import EmbraceStorageInternal
import TestSupport
import XCTest

@testable import EmbraceCore
@testable import EmbraceUploadInternal

/// Device clocks get adjusted — by the user, or by time synchronization correcting a device that
/// drifted while it was off — and when that happens mid-session every duration and ordering derived
/// from the wall clock is wrong. These tests cover the measurement that reports it: that a part
/// carries the movement that happened during it, that each part is measured in isolation, and that a
/// part with nothing trustworthy to report says nothing rather than reporting a zero that would be
/// indistinguishable from a clock that never moved.
final class SessionClockDriftTests: XCTestCase {

    private var storage: EmbraceStorage!
    private let sdkStateProvider = MockEmbraceSDKStateProvider()

    /// `SessionController.otel` is `weak`, so the test has to own the mock for the span to survive
    /// long enough for the session to start.
    private var otel: MockOTelSignalsHandler!

    /// `uploadSessionNoLock` bails when the controller has no upload module, and then the uploader
    /// is never handed the ended part — so the controller needs a real one even though
    /// `MockSessionUploader` never sends anything over it.
    private var upload: EmbraceUpload!

    /// Wall and monotonic clocks the test drives independently, so it can move one without the other.
    private final class TestClocks {
        var wall = Date(timeIntervalSince1970: 1_700_000_000)
        var monoNanos: UInt64 = 1_000_000_000

        /// Time passing with the device clock untouched.
        func tick(seconds: TimeInterval) {
            wall = wall.addingTimeInterval(seconds)
            monoNanos += UInt64(seconds * 1_000_000_000)
        }

        /// The device clock being adjusted, with no real time passing.
        func shiftWallClock(seconds: TimeInterval) {
            wall = wall.addingTimeInterval(seconds)
        }
    }

    override func setUpWithError() throws {
        storage = try EmbraceStorage.createInMemoryDb()
        sdkStateProvider.isEnabled = true
        otel = MockOTelSignalsHandler()

        let urlSessionConfig = URLSessionConfiguration.ephemeral
        urlSessionConfig.httpMaximumConnectionsPerHost = .max
        urlSessionConfig.protocolClasses = [EmbraceHTTPMock.self]

        upload = try EmbraceUpload(
            options: EmbraceUpload.Options(
                endpoints: EmbraceUpload.EndpointOptions(
                    spansURL: URL(string: "https://embrace.\(testName).com/clock_drift/sessions")!,
                    logsURL: URL(string: "https://embrace.\(testName).com/clock_drift/logs")!,
                    attachmentsURL: URL(string: "https://embrace.\(testName).com/clock_drift/attachments")!
                ),
                cache: EmbraceUpload.CacheOptions(
                    storageMechanism: .inMemory(name: testName),
                    enableBackgroundTasks: false
                ),
                metadata: EmbraceUpload.MetadataOptions(apiKey: "apiKey", userAgent: "userAgent", deviceId: "12345678"),
                redundancy: EmbraceUpload.RedundancyOptions(automaticRetryCount: -1),
                urlSessionConfiguration: urlSessionConfig
            ),
            logger: MockLogger(),
            queue: DispatchQueue(label: "io.embrace.tests.clockDrift.upload")
        )
    }

    override func tearDownWithError() throws {
        upload = nil
        storage = nil
        otel = nil
    }

    private func makeController(
        clocks: TestClocks,
        uploader: MockSessionUploader
    ) -> SessionController {
        let controller = SessionController(
            storage: storage,
            upload: upload,
            uploader: uploader,
            config: nil,
            clock: EmbraceClock(wallProvider: { clocks.wall }, monoProvider: { clocks.monoNanos })
        )
        controller.sdkStateProvider = sdkStateProvider
        controller.otel = otel
        return controller
    }

    // MARK: - Measurement on the part record

    func test_endSession_recordsClockDriftOnThePart() throws {
        let clocks = TestClocks()
        let uploader = MockSessionUploader()
        let controller = makeController(clocks: clocks, uploader: uploader)

        controller.startSession(state: .foreground)
        clocks.tick(seconds: 30)
        clocks.shiftWallClock(seconds: 240)
        controller.endSession()
        controller.queue.sync {}

        XCTAssertEqual(uploader.uploadedSession?.clockDriftMs, 240_000)
    }

    func test_endSession_whenClockDidNotMove_recordsZeroDrift() throws {
        let clocks = TestClocks()
        let uploader = MockSessionUploader()
        let controller = makeController(clocks: clocks, uploader: uploader)

        controller.startSession(state: .foreground)
        clocks.tick(seconds: 30)
        controller.endSession()
        controller.queue.sync {}

        XCTAssertEqual(uploader.uploadedSession?.clockDriftMs, 0)
    }

    /// A clock correction during one part must not be re-reported by every part after it — otherwise a
    /// single adjustment at launch would look like a device whose clock never stops moving.
    func test_endSession_eachPartReportsOnlyItsOwnInterval() throws {
        let clocks = TestClocks()
        let uploader = MockSessionUploader()
        let controller = makeController(clocks: clocks, uploader: uploader)

        controller.startSession(state: .foreground)
        clocks.tick(seconds: 30)
        clocks.shiftWallClock(seconds: 240)
        controller.endSession()
        controller.queue.sync {}
        XCTAssertEqual(uploader.uploadedSession?.clockDriftMs, 240_000)

        controller.startSession(state: .foreground)
        clocks.tick(seconds: 60)
        controller.endSession()
        controller.queue.sync {}
        XCTAssertEqual(uploader.uploadedSession?.clockDriftMs, 0)
    }

    func test_endSession_whenClockMovedBackwards_recordsNegativeDrift() throws {
        let clocks = TestClocks()
        let uploader = MockSessionUploader()
        let controller = makeController(clocks: clocks, uploader: uploader)

        controller.startSession(state: .foreground)
        clocks.tick(seconds: 30)
        clocks.shiftWallClock(seconds: -90)
        controller.endSession()
        controller.queue.sync {}

        XCTAssertEqual(uploader.uploadedSession?.clockDriftMs, -90_000)
    }

    // MARK: - Payload

    func test_payload_whenDriftWasMeasured_emitsTheAttribute() throws {
        let session = MockSession.with(id: TestConstants.sessionId, state: .foreground)
        session.clockDriftMs = 240_000

        let payload = SessionSpanUtils.payload(from: session)

        XCTAssertEqual(
            payload.attributes.first { $0.key == SpanSemantics.Session.keyClockMonotonicDrift }?.value,
            "240000"
        )
    }

    func test_payload_whenDriftIsNegative_emitsTheSignedValue() throws {
        let session = MockSession.with(id: TestConstants.sessionId, state: .foreground)
        session.clockDriftMs = -90_000

        let payload = SessionSpanUtils.payload(from: session)

        XCTAssertEqual(
            payload.attributes.first { $0.key == SpanSemantics.Session.keyClockMonotonicDrift }?.value,
            "-90000"
        )
    }

    /// Nothing measured means the key is absent, not zero: a part recovered from an earlier process
    /// has no anchor to measure against, and reporting `0` would claim its clock held steady.
    func test_payload_whenDriftWasNotMeasured_omitsTheAttribute() throws {
        let session = MockSession.with(id: TestConstants.sessionId, state: .foreground)
        XCTAssertNil(session.clockDriftMs)

        let payload = SessionSpanUtils.payload(from: session)

        XCTAssertNil(payload.attributes.first { $0.key == SpanSemantics.Session.keyClockMonotonicDrift })
    }
}
