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

final class UserSessionControllerTests: XCTestCase {

    var storage: EmbraceStorage!
    var config: MockEmbraceConfigurable!

    /// Reference time the controller's injected clock returns. Tests bump it directly.
    var now: Date = Date(timeIntervalSince1970: 1_700_000_000)

    /// 12h max, 30min inactivity.
    static let defaultMax: TimeInterval = 12 * 3600
    static let defaultInactivity: TimeInterval = 30 * 60

    override func setUpWithError() throws {
        storage = try EmbraceStorage.createInMemoryDb()
        config = MockEmbraceConfigurable(
            userSessionMaxDuration: Self.defaultMax,
            userSessionInactivityTimeout: Self.defaultInactivity
        )
    }

    override func tearDownWithError() throws {
        storage.coreData.destroy()
        storage = nil
        config = nil
    }

    private func makeController() -> UserSessionController {
        return UserSessionController(storage: storage, config: config) { [unowned self] in self.now }
    }

    // MARK: - attachPart decision tree

    func testAttachPart_noActiveUserSession_createsNewOne() {
        let controller = makeController()
        let snapshot = controller.attachPart(state: .foreground, startTime: now)

        XCTAssertEqual(snapshot.partIndex, 1)
        XCTAssertEqual(snapshot.maxDuration, Self.defaultMax)
        XCTAssertEqual(snapshot.inactivityTimeout, Self.defaultInactivity)
        XCTAssertNil(snapshot.lastForegroundPartEnd)
        XCTAssertNil(snapshot.endTime)
        XCTAssertNil(snapshot.terminationReason)

        // The notification is posted via DispatchQueue.main.async inside attachPart, so it's
        // queued but not yet delivered when attachPart returns. The handler runs when wait()
        // drives the runloop; filtering by snapshot.id avoids matching cross-test leakage.
        var captured: EmbraceUserSession?
        let startExp = expectation(forNotification: .embraceUserSessionDidStart, object: nil) { notif in
            guard let snap = notif.object as? EmbraceUserSession, snap.id == snapshot.id else { return false }
            captured = snap
            return true
        }
        wait(for: [startExp], timeout: 1)

        XCTAssertEqual(captured?.partIndex, 1)
        XCTAssertEqual(captured?.maxDuration, Self.defaultMax)
        XCTAssertEqual(captured?.inactivityTimeout, Self.defaultInactivity)
        XCTAssertEqual(captured?.startTime, now)
        XCTAssertNil(captured?.lastForegroundPartEnd)
        XCTAssertNil(captured?.endTime)
        XCTAssertNil(captured?.terminationReason)
    }

    func testAttachPart_activeWithinBounds_invalidatesInactivityCutoff() {
        let controller = makeController()

        let first = controller.attachPart(state: .foreground, startTime: now)
        controller.markForegroundPartEnded(at: now.addingTimeInterval(60))

        // Sanity: the snapshot now has a non-nil lastForegroundPartEnd before next attach.
        XCTAssertNotNil(controller.currentUserSession?.lastForegroundPartEnd)

        now = now.addingTimeInterval(120)
        let second = controller.attachPart(state: .foreground, startTime: now)

        // Same user session (id unchanged), part index bumped, inactivity cutoff cleared.
        // The behavioral evidence here proves no new user session was started; the start
        // notification side of that is covered by `testAttachPart_noActiveUserSession_createsNewOne`.
        XCTAssertEqual(second.id, first.id, "Same user session")
        XCTAssertEqual(second.partIndex, 2)
        XCTAssertNil(second.lastForegroundPartEnd, "Inactivity cutoff cleared at part start")
    }

    func testAttachPart_expiredByMaxDuration_endsAndCreatesNew() {
        let controller = makeController()
        let first = controller.attachPart(state: .foreground, startTime: now)

        var captured: EmbraceUserSession?
        let endExp = expectation(forNotification: .embraceUserSessionDidEnd, object: nil) { notif in
            guard let snap = notif.object as? EmbraceUserSession, snap.id == first.id else { return false }
            captured = snap
            return true
        }

        // jump 13h — past 12h max duration
        now = now.addingTimeInterval(13 * 3600)
        let second = controller.attachPart(state: .foreground, startTime: now)

        XCTAssertNotEqual(second.id, first.id)
        XCTAssertEqual(second.partIndex, 1)

        wait(for: [endExp], timeout: 1)

        XCTAssertEqual(captured?.id, first.id)
        XCTAssertEqual(captured?.terminationReason, .maxDurationReached)
        XCTAssertEqual(captured?.endTime, now)
    }

    func testAttachPart_expiredByInactivity_endsAndCreatesNew() {
        let controller = makeController()
        let first = controller.attachPart(state: .foreground, startTime: now)

        // foreground part ended at +5min
        controller.markForegroundPartEnded(at: now.addingTimeInterval(300))

        var captured: EmbraceUserSession?
        let endExp = expectation(forNotification: .embraceUserSessionDidEnd, object: nil) { notif in
            guard let snap = notif.object as? EmbraceUserSession, snap.id == first.id else { return false }
            captured = snap
            return true
        }

        // next part start is 31min after the foreground end → past 30min inactivity timeout
        now = now.addingTimeInterval(300 + 31 * 60)
        let second = controller.attachPart(state: .foreground, startTime: now)

        XCTAssertNotEqual(second.id, first.id)
        XCTAssertEqual(second.partIndex, 1)
        wait(for: [endExp], timeout: 1)

        XCTAssertEqual(captured?.id, first.id)
        XCTAssertEqual(captured?.terminationReason, .inactivity)
        XCTAssertEqual(captured?.endTime, now)
    }

    func testAttachPart_clockAnomaly_endsAndCreatesNew() {
        let controller = makeController()
        let first = controller.attachPart(state: .foreground, startTime: now)

        var captured: EmbraceUserSession?
        let endExp = expectation(forNotification: .embraceUserSessionDidEnd, object: nil) { notif in
            guard let snap = notif.object as? EmbraceUserSession, snap.id == first.id else { return false }
            captured = snap
            return true
        }

        // device clock moves backward
        now = now.addingTimeInterval(-3600)
        let second = controller.attachPart(state: .foreground, startTime: now)

        XCTAssertNotEqual(second.id, first.id)
        XCTAssertEqual(second.partIndex, 1)
        wait(for: [endExp], timeout: 1)

        XCTAssertEqual(captured?.id, first.id)
        XCTAssertEqual(captured?.terminationReason, .clockAnomaly)
        XCTAssertEqual(captured?.endTime, now)
    }

    func testAttachPart_clockJumpedBackBetweenStartAndLastFgEnd_endsAndCreatesNew() {
        // Sequence: user session starts at T0, foreground part ends at T0+5min (installing
        // an inactivity cutoff at lastFgEnd = T0+5min), then the device clock jumps backward
        // to T0+2min — still after `startTime` but BEFORE `lastForegroundPartEnd`. Without the
        // lastForegroundPartEnd-in-future guard, the inactivity comparison (`now >= lastFgEnd
        // + timeout`) is always false and the user session survives until max-duration fires.
        let controller = makeController()
        let first = controller.attachPart(state: .foreground, startTime: now)
        let lastFgEnd = now.addingTimeInterval(300)  // T0 + 5min
        controller.markForegroundPartEnded(at: lastFgEnd)

        var captured: EmbraceUserSession?
        let endExp = expectation(forNotification: .embraceUserSessionDidEnd, object: nil) { notif in
            guard let snap = notif.object as? EmbraceUserSession, snap.id == first.id else { return false }
            captured = snap
            return true
        }

        // Clock jumps backward to T0 + 2min — past `startTime` but before `lastFgEnd`.
        now = now.addingTimeInterval(120)
        let second = controller.attachPart(state: .foreground, startTime: now)

        XCTAssertNotEqual(second.id, first.id)
        XCTAssertEqual(second.partIndex, 1)
        wait(for: [endExp], timeout: 1)

        XCTAssertEqual(captured?.id, first.id)
        XCTAssertEqual(captured?.terminationReason, .clockAnomaly)
        XCTAssertEqual(captured?.endTime, now)
    }

    func testAttachPart_partIndexMonotonic() {
        let controller = makeController()
        var indices: [EMBInt] = []

        for i in 0..<5 {
            now = now.addingTimeInterval(TimeInterval(i * 60))
            indices.append(controller.attachPart(state: .foreground, startTime: now).partIndex)
        }

        XCTAssertEqual(indices, [1, 2, 3, 4, 5])
    }

    // MARK: - bootstrap

    func testBootstrap_emptyStorage_leavesNoActiveUserSession() {
        let controller = makeController()
        controller.bootstrap()
        XCTAssertNil(controller.currentUserSession)
    }

    func testBootstrap_legacyRowMissingUserSessionColumns_leavesNoActiveUserSession() {
        let exp = expectation(description: "addSession")
        storage.addSession(
            id: TestConstants.sessionId,
            processId: ProcessIdentifier.current,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: now.addingTimeInterval(-60)
        ) { exp.fulfill() }
        wait(for: [exp], timeout: 1)

        let controller = makeController()
        controller.bootstrap()
        XCTAssertNil(controller.currentUserSession)
    }

    func testBootstrap_validRecentRecord_reconstructsSnapshot() {
        let userSessionId = EmbraceIdentifier.random
        let userSessionStart = now.addingTimeInterval(-3600)
        let exp = expectation(description: "addSession")
        storage.addSession(
            id: TestConstants.sessionId,
            processId: ProcessIdentifier.current,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: userSessionStart,
            sessionNumber: 7,
            userSessionId: userSessionId,
            userSessionStartTime: userSessionStart,
            userSessionMaxDuration: Self.defaultMax,
            userSessionInactivityTimeout: Self.defaultInactivity,
            userSessionPartIndex: 3
        ) { exp.fulfill() }
        wait(for: [exp], timeout: 1)

        let controller = makeController()
        controller.bootstrap()

        let snapshot = controller.currentUserSession
        XCTAssertEqual(snapshot?.id, userSessionId)
        XCTAssertEqual(snapshot?.startTime.timeIntervalSince1970 ?? 0, userSessionStart.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(snapshot?.maxDuration, Self.defaultMax)
        XCTAssertEqual(snapshot?.inactivityTimeout, Self.defaultInactivity)
        XCTAssertEqual(snapshot?.partIndex, 3)
    }

    func testBootstrap_expiredByMax_dropsSnapshot() {
        let exp = expectation(description: "addSession")
        storage.addSession(
            id: TestConstants.sessionId,
            processId: ProcessIdentifier.current,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: now.addingTimeInterval(-13 * 3600),
            userSessionId: EmbraceIdentifier.random,
            userSessionStartTime: now.addingTimeInterval(-13 * 3600),
            userSessionMaxDuration: Self.defaultMax,
            userSessionInactivityTimeout: Self.defaultInactivity,
            userSessionPartIndex: 1
        ) { exp.fulfill() }
        wait(for: [exp], timeout: 1)

        let controller = makeController()
        controller.bootstrap()
        XCTAssertNil(controller.currentUserSession)
    }

    func testBootstrap_expiredSnapshot_backfillsTerminationReasonOnLatestPart() throws {
        // Need a SessionController wired in so backfillTerminationReasonOnLatestPart can write
        // through to storage.
        let sdkStateProvider = MockEmbraceSDKStateProvider()
        let otel = MockOTelSignalsHandler()
        let realSessionController = SessionController(storage: storage, upload: nil, config: nil)
        realSessionController.sdkStateProvider = sdkStateProvider
        realSessionController.otel = otel

        let exp = expectation(description: "addSession")
        storage.addSession(
            id: TestConstants.sessionId,
            processId: ProcessIdentifier.current,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: now.addingTimeInterval(-13 * 3600),
            userSessionId: EmbraceIdentifier.random,
            userSessionStartTime: now.addingTimeInterval(-13 * 3600),
            userSessionMaxDuration: Self.defaultMax,
            userSessionInactivityTimeout: Self.defaultInactivity,
            userSessionPartIndex: 1
        ) { exp.fulfill() }
        wait(for: [exp], timeout: 1)

        let controller = makeController()
        controller.sessionController = realSessionController
        controller.bootstrap()

        XCTAssertNil(controller.currentUserSession)

        // Wait for the async backfill to land.
        let drained = expectation(description: "backfill landed")
        storage.coreData.performAsyncOperation { _ in drained.fulfill() }
        wait(for: [drained], timeout: 1)

        let stored = storage.fetchSession(id: TestConstants.sessionId)
        XCTAssertEqual(stored?.userSessionTerminationReason, .maxDurationReached)
    }

    func testBootstrap_expiredSnapshot_doesNotOverwriteExistingTerminationReason() throws {
        let sdkStateProvider = MockEmbraceSDKStateProvider()
        let otel = MockOTelSignalsHandler()
        let realSessionController = SessionController(storage: storage, upload: nil, config: nil)
        realSessionController.sdkStateProvider = sdkStateProvider
        realSessionController.otel = otel

        // Prior process recorded `.manual` on the last part before dying.
        let exp = expectation(description: "addSession")
        storage.addSession(
            id: TestConstants.sessionId,
            processId: ProcessIdentifier.current,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: now.addingTimeInterval(-13 * 3600),
            userSessionId: EmbraceIdentifier.random,
            userSessionStartTime: now.addingTimeInterval(-13 * 3600),
            userSessionMaxDuration: Self.defaultMax,
            userSessionInactivityTimeout: Self.defaultInactivity,
            userSessionPartIndex: 1,
            userSessionTerminationReason: .manual
        ) { exp.fulfill() }
        wait(for: [exp], timeout: 1)

        let controller = makeController()
        controller.sessionController = realSessionController
        controller.bootstrap()

        let drained = expectation(description: "drained")
        storage.coreData.performAsyncOperation { _ in drained.fulfill() }
        wait(for: [drained], timeout: 1)

        // .manual stands; bootstrap's .maxDurationReached did not overwrite it.
        let stored = storage.fetchSession(id: TestConstants.sessionId)
        XCTAssertEqual(stored?.userSessionTerminationReason, .manual)
    }

    func testBootstrap_clockAnomaly_dropsSnapshot() {
        let exp = expectation(description: "addSession")
        storage.addSession(
            id: TestConstants.sessionId,
            processId: ProcessIdentifier.current,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: now.addingTimeInterval(3600),
            userSessionId: EmbraceIdentifier.random,
            userSessionStartTime: now.addingTimeInterval(3600),
            userSessionMaxDuration: Self.defaultMax,
            userSessionInactivityTimeout: Self.defaultInactivity,
            userSessionPartIndex: 1
        ) { exp.fulfill() }
        wait(for: [exp], timeout: 1)

        let controller = makeController()
        controller.bootstrap()
        XCTAssertNil(controller.currentUserSession)
    }

    // MARK: - end / idempotency

    func testEndActiveUserSession_isIdempotent() {
        let controller = makeController()
        let first = controller.attachPart(state: .foreground, startTime: now)

        // Handler keeps returning true for every match. If a second end actually fired (i.e.
        // the second call wasn't a no-op), assertForOverFulfill would trip.
        var captured: [EmbraceUserSession] = []
        let endExp = expectation(forNotification: .embraceUserSessionDidEnd, object: nil) { notif in
            guard let snap = notif.object as? EmbraceUserSession, snap.id == first.id else { return false }
            captured.append(snap)
            return true
        }
        endExp.assertForOverFulfill = true

        controller.endActiveUserSession(reason: .manual, at: now)
        controller.endActiveUserSession(reason: .manual, at: now)  // no-op

        XCTAssertNil(controller.currentUserSession)
        wait(for: [endExp], timeout: 1)

        XCTAssertEqual(captured.count, 1)
        XCTAssertEqual(captured.first?.id, first.id)
        XCTAssertEqual(captured.first?.terminationReason, .manual)
        XCTAssertEqual(captured.first?.endTime, now)
    }

    func testEndActiveUserSession_resetsPartIndexOnNextAttach() {
        let controller = makeController()
        _ = controller.attachPart(state: .foreground, startTime: now)
        _ = controller.attachPart(state: .foreground, startTime: now)
        controller.endActiveUserSession(reason: .manual, at: now)

        let next = controller.attachPart(state: .foreground, startTime: now)
        XCTAssertEqual(next.partIndex, 1)
    }

    // MARK: - manual-end rate limit

    func testCanManuallyEnd_firstCallAllowed() {
        let controller = makeController()
        XCTAssertTrue(controller.canManuallyEnd(now: now))
    }

    func testCanManuallyEnd_within5sBlocked() {
        let controller = makeController()
        XCTAssertTrue(controller.canManuallyEnd(now: now))
        XCTAssertFalse(controller.canManuallyEnd(now: now.addingTimeInterval(4)))
    }

    func testCanManuallyEnd_after5sAllowed() {
        let controller = makeController()
        XCTAssertTrue(controller.canManuallyEnd(now: now))
        XCTAssertTrue(controller.canManuallyEnd(now: now.addingTimeInterval(5)))
    }

    // MARK: - foreground tracking

    func testMarkForegroundPartEnded_updatesSnapshot() {
        let controller = makeController()
        _ = controller.attachPart(state: .foreground, startTime: now)
        let endTime = now.addingTimeInterval(120)
        controller.markForegroundPartEnded(at: endTime)
        XCTAssertEqual(controller.currentUserSession?.lastForegroundPartEnd, endTime)
    }

    func testMarkForegroundPartEnded_noActiveUserSession_isNoop() {
        let controller = makeController()
        controller.markForegroundPartEnded(at: now)  // must not crash
        XCTAssertNil(controller.currentUserSession)
    }
}
