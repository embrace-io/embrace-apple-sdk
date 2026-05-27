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

    func testAttachPart_withinBounds_postsNoNotifications() {
        // A within-bounds attach bumps `partIndex` on the same user session — it must NOT post
        // either didStart or didEnd. (Single-didStart-per-user-session invariant.)
        let controller = makeController()

        // Drain the didStart fired by the first attach.
        let firstStart = expectation(forNotification: .embraceUserSessionDidStart, object: nil) { _ in true }
        let first = controller.attachPart(state: .foreground, startTime: now)
        wait(for: [firstStart], timeout: 1)

        let noStart = expectation(forNotification: .embraceUserSessionDidStart, object: nil) { notif in
            (notif.object as? EmbraceUserSession)?.id == first.id
        }
        noStart.isInverted = true
        let noEnd = expectation(forNotification: .embraceUserSessionDidEnd, object: nil) { notif in
            (notif.object as? EmbraceUserSession)?.id == first.id
        }
        noEnd.isInverted = true

        now = now.addingTimeInterval(60)
        let second = controller.attachPart(state: .foreground, startTime: now)
        XCTAssertEqual(second.id, first.id, "sanity: same user session")
        XCTAssertEqual(second.partIndex, 2)

        wait(for: [noStart, noEnd], timeout: 0.5)
    }

    func testAttachPart_expiredAndRolled_postsDidStartForNewUserSession() {
        // Complement to the within-bounds invariant: when attachPart starts a new user session
        // (after expiry), didStart IS posted for the new id with partIndex == 1.
        let controller = makeController()
        let first = controller.attachPart(state: .foreground, startTime: now)

        now = now.addingTimeInterval(13 * 3600)  // past 12h max

        var capturedNewStart: EmbraceUserSession?
        let newStart = expectation(forNotification: .embraceUserSessionDidStart, object: nil) { notif in
            guard let snap = notif.object as? EmbraceUserSession, snap.id != first.id else { return false }
            capturedNewStart = snap
            return true
        }

        let second = controller.attachPart(state: .foreground, startTime: now)
        XCTAssertNotEqual(second.id, first.id)

        wait(for: [newStart], timeout: 1)
        XCTAssertEqual(capturedNewStart?.id, second.id)
        XCTAssertEqual(capturedNewStart?.partIndex, 1)
        XCTAssertEqual(capturedNewStart?.startTime, now)
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

    func testAttachPart_backgroundJoiningActiveUserSession_preservesLastForegroundPartEnd() {
        // Background parts must preserve `lastForegroundPartEnd` so the next foreground
        // transition can still apply the bg-split cutoff math. This is the `bumping(partIndex:)`
        // path, versus `cleared(partIndex:)` for foreground.
        let controller = makeController()
        let first = controller.attachPart(state: .foreground, startTime: now)
        let fgEnd = now.addingTimeInterval(60)
        controller.markForegroundPartEnded(at: fgEnd)
        XCTAssertEqual(controller.currentUserSession?.lastForegroundPartEnd, fgEnd)

        now = now.addingTimeInterval(120)
        let second = controller.attachPart(state: .background, startTime: now)

        XCTAssertEqual(second.id, first.id)
        XCTAssertEqual(second.partIndex, 2)
        XCTAssertEqual(second.lastForegroundPartEnd, fgEnd, "bg part must preserve fg cutoff")
        XCTAssertEqual(controller.currentUserSession?.lastForegroundPartEnd, fgEnd)
    }

    func testAttachPart_backgroundAsFirstPartOfNewUserSession() {
        // When no user session is active, a bg part still starts a brand-new user session
        // with partIndex == 1 and no inactivity cutoff.
        let controller = makeController()
        let snapshot = controller.attachPart(state: .background, startTime: now)

        XCTAssertEqual(snapshot.partIndex, 1)
        XCTAssertNil(snapshot.lastForegroundPartEnd)
        XCTAssertEqual(snapshot.startTime, now)
        XCTAssertNil(snapshot.endTime)
        XCTAssertNil(snapshot.terminationReason)
    }

    func testAttachPart_backgroundExpiredByMaxDuration_endsAndCreatesNew() {
        let controller = makeController()
        let first = controller.attachPart(state: .foreground, startTime: now)

        var captured: EmbraceUserSession?
        let endExp = expectation(forNotification: .embraceUserSessionDidEnd, object: nil) { notif in
            guard let snap = notif.object as? EmbraceUserSession, snap.id == first.id else { return false }
            captured = snap
            return true
        }

        // jump 13h — past 12h max duration; next part is background
        now = now.addingTimeInterval(13 * 3600)
        let second = controller.attachPart(state: .background, startTime: now)

        XCTAssertNotEqual(second.id, first.id)
        XCTAssertEqual(second.partIndex, 1)

        wait(for: [endExp], timeout: 1)
        XCTAssertEqual(captured?.terminationReason, .maxDurationReached)
        XCTAssertEqual(captured?.endTime, now)
    }

    func testAttachPart_backgroundExpiredByInactivity_endsAndCreatesNew() {
        let controller = makeController()
        let first = controller.attachPart(state: .foreground, startTime: now)
        controller.markForegroundPartEnded(at: now.addingTimeInterval(300))

        var captured: EmbraceUserSession?
        let endExp = expectation(forNotification: .embraceUserSessionDidEnd, object: nil) { notif in
            guard let snap = notif.object as? EmbraceUserSession, snap.id == first.id else { return false }
            captured = snap
            return true
        }

        // next part is bg, 31min after fg-end → past 30min inactivity timeout
        now = now.addingTimeInterval(300 + 31 * 60)
        let second = controller.attachPart(state: .background, startTime: now)

        XCTAssertNotEqual(second.id, first.id)
        XCTAssertEqual(second.partIndex, 1)

        wait(for: [endExp], timeout: 1)
        XCTAssertEqual(captured?.terminationReason, .inactivity)
        XCTAssertEqual(captured?.endTime, now)
    }

    func testAttachPart_backgroundClockAnomaly_endsAndCreatesNew() {
        let controller = makeController()
        let first = controller.attachPart(state: .foreground, startTime: now)

        var captured: EmbraceUserSession?
        let endExp = expectation(forNotification: .embraceUserSessionDidEnd, object: nil) { notif in
            guard let snap = notif.object as? EmbraceUserSession, snap.id == first.id else { return false }
            captured = snap
            return true
        }

        // device clock moves backward; next part is bg
        now = now.addingTimeInterval(-3600)
        let second = controller.attachPart(state: .background, startTime: now)

        XCTAssertNotEqual(second.id, first.id)
        XCTAssertEqual(second.partIndex, 1)

        wait(for: [endExp], timeout: 1)
        XCTAssertEqual(captured?.terminationReason, .clockAnomaly)
        XCTAssertEqual(captured?.endTime, now)
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

    func testAttachPart_atExactMaxEndBoundary_expires() {
        // `expiryReason` uses `now >= maxEnd` (inclusive). A part starting exactly at the
        // max-duration cutoff must terminate the user session.
        let controller = makeController()
        let first = controller.attachPart(state: .foreground, startTime: now)

        var captured: EmbraceUserSession?
        let endExp = expectation(forNotification: .embraceUserSessionDidEnd, object: nil) { notif in
            guard let snap = notif.object as? EmbraceUserSession, snap.id == first.id else { return false }
            captured = snap
            return true
        }

        // Exactly at maxEnd.
        now = now.addingTimeInterval(Self.defaultMax)
        let second = controller.attachPart(state: .foreground, startTime: now)

        XCTAssertNotEqual(second.id, first.id)
        wait(for: [endExp], timeout: 1)
        XCTAssertEqual(captured?.terminationReason, .maxDurationReached)
    }

    func testAttachPart_justInsideMaxEnd_doesNotExpire() {
        // 1ms before maxEnd: user session must survive.
        let controller = makeController()
        let first = controller.attachPart(state: .foreground, startTime: now)

        now = now.addingTimeInterval(Self.defaultMax - 0.001)
        let second = controller.attachPart(state: .foreground, startTime: now)

        XCTAssertEqual(second.id, first.id)
        XCTAssertEqual(second.partIndex, 2)
    }

    func testAttachPart_atExactInactivityBoundary_expires() {
        // `now >= lastFgEnd + inactivityTimeout` (inclusive). A part starting exactly at the
        // inactivity cutoff must terminate the user session.
        let controller = makeController()
        let first = controller.attachPart(state: .foreground, startTime: now)
        let fgEnd = now.addingTimeInterval(60)
        controller.markForegroundPartEnded(at: fgEnd)

        var captured: EmbraceUserSession?
        let endExp = expectation(forNotification: .embraceUserSessionDidEnd, object: nil) { notif in
            guard let snap = notif.object as? EmbraceUserSession, snap.id == first.id else { return false }
            captured = snap
            return true
        }

        // Exactly at lastFgEnd + inactivityTimeout.
        now = fgEnd.addingTimeInterval(Self.defaultInactivity)
        let second = controller.attachPart(state: .foreground, startTime: now)

        XCTAssertNotEqual(second.id, first.id)
        wait(for: [endExp], timeout: 1)
        XCTAssertEqual(captured?.terminationReason, .inactivity)
    }

    func testAttachPart_justInsideInactivityCutoff_doesNotExpire() {
        // 1ms before the inactivity cutoff: user session must survive.
        let controller = makeController()
        let first = controller.attachPart(state: .foreground, startTime: now)
        let fgEnd = now.addingTimeInterval(60)
        controller.markForegroundPartEnded(at: fgEnd)

        now = fgEnd.addingTimeInterval(Self.defaultInactivity - 0.001)
        let second = controller.attachPart(state: .foreground, startTime: now)

        XCTAssertEqual(second.id, first.id)
        XCTAssertEqual(second.partIndex, 2)
    }

    func testAttachPart_maxAndInactivityBothCrossed_maxWins() {
        // When both `maxEnd` and `inactivityCutoff` are crossed, `expiryReason` checks `maxEnd`
        // first → `.maxDurationReached` wins. (Clock-anomaly precedence cannot be tested against
        // these because `now < startTime` / `now < lastFgEnd` precludes `now >= maxEnd` and
        // `now >= inactivityCutoff` by construction.)
        let controller = makeController()
        let first = controller.attachPart(state: .foreground, startTime: now)
        controller.markForegroundPartEnded(at: now.addingTimeInterval(60))  // inactivity cutoff at T0+60+30min

        var captured: EmbraceUserSession?
        let endExp = expectation(forNotification: .embraceUserSessionDidEnd, object: nil) { notif in
            guard let snap = notif.object as? EmbraceUserSession, snap.id == first.id else { return false }
            captured = snap
            return true
        }

        // 13h: past both maxEnd (12h) and inactivityCutoff (~31min).
        now = now.addingTimeInterval(13 * 3600)
        _ = controller.attachPart(state: .foreground, startTime: now)

        wait(for: [endExp], timeout: 1)
        XCTAssertEqual(captured?.terminationReason, .maxDurationReached, "max wins over inactivity")
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

    func testAttachPart_mixedForegroundBackgroundSequence_partIndexAccumulates() {
        // `partIndex` bumps regardless of state. `lastForegroundPartEnd` survives across a bg
        // part (`bumping` path) and is cleared on the next fg part (`cleared` path).
        let controller = makeController()
        let userSession = controller.attachPart(state: .foreground, startTime: now)
        XCTAssertEqual(userSession.partIndex, 1)

        // fg ends at +60s — installs the inactivity cutoff.
        let fgEnd = now.addingTimeInterval(60)
        controller.markForegroundPartEnded(at: fgEnd)

        // bg part bumps to 2 and preserves lastForegroundPartEnd.
        now = now.addingTimeInterval(120)
        let bg1 = controller.attachPart(state: .background, startTime: now)
        XCTAssertEqual(bg1.id, userSession.id)
        XCTAssertEqual(bg1.partIndex, 2)
        XCTAssertEqual(bg1.lastForegroundPartEnd, fgEnd)

        // fg part bumps to 3 and clears lastForegroundPartEnd.
        now = now.addingTimeInterval(60)
        let fg2 = controller.attachPart(state: .foreground, startTime: now)
        XCTAssertEqual(fg2.id, userSession.id)
        XCTAssertEqual(fg2.partIndex, 3)
        XCTAssertNil(fg2.lastForegroundPartEnd)

        // bg part bumps to 4 and preserves the (now-nil) lastForegroundPartEnd.
        now = now.addingTimeInterval(60)
        let bg2 = controller.attachPart(state: .background, startTime: now)
        XCTAssertEqual(bg2.id, userSession.id)
        XCTAssertEqual(bg2.partIndex, 4)
        XCTAssertNil(bg2.lastForegroundPartEnd)
    }

    // MARK: - bootstrap

    func testBootstrap_emptyStorage_leavesNoActiveUserSession() {
        let controller = makeController()
        controller.bootstrap(priorSession: storage.fetchLatestSession())
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
        controller.bootstrap(priorSession: storage.fetchLatestSession())
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
        controller.bootstrap(priorSession: storage.fetchLatestSession())

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
        controller.bootstrap(priorSession: storage.fetchLatestSession())
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
        controller.bootstrap(priorSession: storage.fetchLatestSession())

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
        controller.bootstrap(priorSession: storage.fetchLatestSession())

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
        controller.bootstrap(priorSession: storage.fetchLatestSession())
        XCTAssertNil(controller.currentUserSession)
    }

    func testBootstrap_storedDurationsWinOverConfig() {
        // The record's stored max/inactivity values are an immutable snapshot of the user
        // session's policy and must win over whatever the current config returns.
        let userSessionStart = now.addingTimeInterval(-60)
        let storedMax: TimeInterval = 99 * 3600
        let storedInactivity: TimeInterval = 99 * 60
        XCTAssertNotEqual(storedMax, config.userSessionMaxDuration)
        XCTAssertNotEqual(storedInactivity, config.userSessionInactivityTimeout)

        let exp = expectation(description: "addSession")
        storage.addSession(
            id: TestConstants.sessionId,
            processId: ProcessIdentifier.current,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: userSessionStart,
            userSessionId: EmbraceIdentifier.random,
            userSessionStartTime: userSessionStart,
            userSessionMaxDuration: storedMax,
            userSessionInactivityTimeout: storedInactivity,
            userSessionPartIndex: 1
        ) { exp.fulfill() }
        wait(for: [exp], timeout: 1)

        let controller = makeController()
        controller.bootstrap(priorSession: storage.fetchLatestSession())

        XCTAssertEqual(controller.currentUserSession?.maxDuration, storedMax)
        XCTAssertEqual(controller.currentUserSession?.inactivityTimeout, storedInactivity)
    }

    func testBootstrap_fallsBackToConfigWhenStoredDurationsNil() {
        // Defensive path: a record may have userSessionId/StartTime but missing duration columns.
        // In that case the controller should fall back to the current config.
        let userSessionStart = now.addingTimeInterval(-60)
        let exp = expectation(description: "addSession")
        storage.addSession(
            id: TestConstants.sessionId,
            processId: ProcessIdentifier.current,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: userSessionStart,
            userSessionId: EmbraceIdentifier.random,
            userSessionStartTime: userSessionStart,
            // userSessionMaxDuration: nil
            // userSessionInactivityTimeout: nil
            userSessionPartIndex: 1
        ) { exp.fulfill() }
        wait(for: [exp], timeout: 1)

        let controller = makeController()
        controller.bootstrap(priorSession: storage.fetchLatestSession())

        XCTAssertEqual(controller.currentUserSession?.maxDuration, config.userSessionMaxDuration)
        XCTAssertEqual(controller.currentUserSession?.inactivityTimeout, config.userSessionInactivityTimeout)
    }

    func testBootstrap_fallsBackToDefaultsWhenStoredAndConfigNil() {
        // `config` is held weakly by UserSessionController. With no strong reference outside
        // the controller, the weak ref nils out and the snapshot falls back to the semantics
        // defaults.
        let userSessionStart = now.addingTimeInterval(-60)
        let exp = expectation(description: "addSession")
        storage.addSession(
            id: TestConstants.sessionId,
            processId: ProcessIdentifier.current,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: userSessionStart,
            userSessionId: EmbraceIdentifier.random,
            userSessionStartTime: userSessionStart,
            userSessionPartIndex: 1
        ) { exp.fulfill() }
        wait(for: [exp], timeout: 1)

        func makeControllerWithEphemeralConfig() -> UserSessionController {
            let tempConfig = MockEmbraceConfigurable(userSessionMaxDuration: 1, userSessionInactivityTimeout: 1)
            return UserSessionController(storage: storage, config: tempConfig) { [unowned self] in self.now }
        }
        let controller = makeControllerWithEphemeralConfig()
        XCTAssertNil(controller.config, "Precondition: weak config must have deallocated")

        controller.bootstrap(priorSession: storage.fetchLatestSession())

        XCTAssertEqual(controller.currentUserSession?.maxDuration, UserSessionSemantics.defaultMaxDurationSeconds)
        XCTAssertEqual(controller.currentUserSession?.inactivityTimeout, UserSessionSemantics.defaultInactivityTimeoutSeconds)
    }

    func testBootstrap_restoresLastForegroundPartEnd() {
        // The fg-end timestamp persisted on the latest part must round-trip into the snapshot,
        // so the next attachPart's inactivity math has the correct cutoff.
        // fgEnd must be recent enough that the snapshot is not already expired by inactivity.
        let userSessionStart = now.addingTimeInterval(-60)
        let fgEnd = now.addingTimeInterval(-30)
        let exp = expectation(description: "addSession")
        storage.addSession(
            id: TestConstants.sessionId,
            processId: ProcessIdentifier.current,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: userSessionStart,
            userSessionId: EmbraceIdentifier.random,
            userSessionStartTime: userSessionStart,
            userSessionMaxDuration: Self.defaultMax,
            userSessionInactivityTimeout: Self.defaultInactivity,
            userSessionLastForegroundEnd: fgEnd,
            userSessionPartIndex: 1
        ) { exp.fulfill() }
        wait(for: [exp], timeout: 1)

        let controller = makeController()
        controller.bootstrap(priorSession: storage.fetchLatestSession())

        XCTAssertEqual(
            controller.currentUserSession?.lastForegroundPartEnd?.timeIntervalSince1970 ?? 0,
            fgEnd.timeIntervalSince1970,
            accuracy: 0.001
        )
    }

    func testBootstrap_partIndexZeroIsFlooredToOne() {
        // `max(latest.userSessionPartIndex, 1)` protects against records that somehow stored 0.
        let userSessionStart = now.addingTimeInterval(-60)
        let exp = expectation(description: "addSession")
        storage.addSession(
            id: TestConstants.sessionId,
            processId: ProcessIdentifier.current,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: userSessionStart,
            userSessionId: EmbraceIdentifier.random,
            userSessionStartTime: userSessionStart,
            userSessionMaxDuration: Self.defaultMax,
            userSessionInactivityTimeout: Self.defaultInactivity,
            userSessionPartIndex: 0
        ) { exp.fulfill() }
        wait(for: [exp], timeout: 1)

        let controller = makeController()
        controller.bootstrap(priorSession: storage.fetchLatestSession())

        XCTAssertEqual(controller.currentUserSession?.partIndex, 1)
    }

    func testBootstrap_expiredByInactivity_backfillsInactivityReason() throws {
        let sdkStateProvider = MockEmbraceSDKStateProvider()
        let otel = MockOTelSignalsHandler()
        let realSessionController = SessionController(storage: storage, upload: nil, config: nil)
        realSessionController.sdkStateProvider = sdkStateProvider
        realSessionController.otel = otel

        // User session well under max but past its inactivity cutoff at bootstrap time.
        let userSessionStart = now.addingTimeInterval(-3600)
        let fgEnd = now.addingTimeInterval(-3000)  // 50min ago, > 30min default inactivity
        let exp = expectation(description: "addSession")
        storage.addSession(
            id: TestConstants.sessionId,
            processId: ProcessIdentifier.current,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: userSessionStart,
            userSessionId: EmbraceIdentifier.random,
            userSessionStartTime: userSessionStart,
            userSessionMaxDuration: Self.defaultMax,
            userSessionInactivityTimeout: Self.defaultInactivity,
            userSessionLastForegroundEnd: fgEnd,
            userSessionPartIndex: 1
        ) { exp.fulfill() }
        wait(for: [exp], timeout: 1)

        let controller = makeController()
        controller.sessionController = realSessionController
        controller.bootstrap(priorSession: storage.fetchLatestSession())

        XCTAssertNil(controller.currentUserSession)

        let drained = expectation(description: "backfill landed")
        storage.coreData.performAsyncOperation { _ in drained.fulfill() }
        wait(for: [drained], timeout: 1)

        let stored = storage.fetchSession(id: TestConstants.sessionId)
        XCTAssertEqual(stored?.userSessionTerminationReason, .inactivity)
    }

    func testBootstrap_expiredByClockAnomaly_backfillsClockAnomalyReason() throws {
        let sdkStateProvider = MockEmbraceSDKStateProvider()
        let otel = MockOTelSignalsHandler()
        let realSessionController = SessionController(storage: storage, upload: nil, config: nil)
        realSessionController.sdkStateProvider = sdkStateProvider
        realSessionController.otel = otel

        // Record's userSessionStartTime is in the future relative to `now` → clock anomaly.
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
        controller.sessionController = realSessionController
        controller.bootstrap(priorSession: storage.fetchLatestSession())

        XCTAssertNil(controller.currentUserSession)

        let drained = expectation(description: "backfill landed")
        storage.coreData.performAsyncOperation { _ in drained.fulfill() }
        wait(for: [drained], timeout: 1)

        let stored = storage.fetchSession(id: TestConstants.sessionId)
        XCTAssertEqual(stored?.userSessionTerminationReason, .clockAnomaly)
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
