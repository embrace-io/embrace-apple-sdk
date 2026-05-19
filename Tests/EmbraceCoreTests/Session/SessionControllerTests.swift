//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceConfigInternal
import EmbraceConfiguration
import EmbraceStorageInternal
import TestSupport
import XCTest

@testable import EmbraceCore
@testable import EmbraceUploadInternal

final class SessionControllerTests: XCTestCase {

    var storage: EmbraceStorage!
    var controller: SessionController!
    var userSessionController: UserSessionController!
    var configurable: MockEmbraceConfigurable!
    var config: EmbraceConfig!
    var upload: EmbraceUpload!
    let sdkStateProvider = MockEmbraceSDKStateProvider()
    var otel: MockOTelSignalsHandler!

    static let testMetadataOptions = EmbraceUpload.MetadataOptions(
        apiKey: "apiKey",
        userAgent: "userAgent",
        deviceId: "12345678"
    )
    static let testRedundancyOptions = EmbraceUpload.RedundancyOptions(automaticRetryCount: -1)

    var uploadTestOptions: EmbraceUpload.Options!

    override func setUpWithError() throws {
        let uploadUrlSessionconfig = URLSessionConfiguration.ephemeral
        uploadUrlSessionconfig.httpMaximumConnectionsPerHost = .max
        uploadUrlSessionconfig.protocolClasses = [EmbraceHTTPMock.self]

        uploadTestOptions = EmbraceUpload.Options(
            endpoints: testEndpointOptions(testName: testName),
            cache: EmbraceUpload.CacheOptions(
                storageMechanism: .inMemory(name: testName), enableBackgroundTasks: false),
            metadata: Self.testMetadataOptions,
            redundancy: Self.testRedundancyOptions,
            urlSessionConfiguration: uploadUrlSessionconfig
        )

        upload = try EmbraceUpload(
            options: uploadTestOptions, logger: MockLogger(), queue: .main)
        storage = try EmbraceStorage.createInMemoryDb()

        sdkStateProvider.isEnabled = true

        otel = MockOTelSignalsHandler()

        // we pass nil so we only use the upload/config module in the relevant tests
        controller = SessionController(storage: storage, upload: nil, config: nil)
        controller.sdkStateProvider = sdkStateProvider
        controller.otel = otel

        // Every part-start in v7 routes through the user-session controller. The default
        // mock config returns 12h max / 30min inactivity so back-to-back startSession calls
        // in the same test stay within the same user session.
        configurable = MockEmbraceConfigurable()
        userSessionController = UserSessionController(storage: storage, config: configurable)
        userSessionController.sessionController = controller
        controller.userSessionController = userSessionController
    }

    override func tearDownWithError() throws {
        storage.coreData.destroy()
        upload.cache.coreData.destroy()
        upload = nil
        controller = nil
    }

    func test_startSession_returnsNewSessionEveryTime() throws {
        let a = controller.startSession(state: .foreground)
        let b = controller.startSession(state: .foreground)
        let c = controller.startSession(state: .foreground)

        XCTAssertNotEqual(a!.id, b!.id)
        XCTAssertNotEqual(a!.id, c!.id)
        XCTAssertNotEqual(b!.id, c!.id)
    }

    func testSDKDisabled_startSession_doesntCreateASession() throws {
        config = EmbraceConfigMock.default(sdkEnabled: false)
        sdkStateProvider.isEnabled = false

        controller = SessionController(
            storage: storage,
            upload: upload,
            config: config
        )
        controller.sdkStateProvider = sdkStateProvider

        let session = controller.startSession(state: .foreground)

        XCTAssertNil(session)
        XCTAssertNil(controller.currentSessionSpan)
    }

    func test_startSession_setsForegroundState() throws {
        let a = controller.startSession(state: .foreground)
        XCTAssertEqual(a!.state, .foreground)
    }

    // MARK: startSession

    func test_startSession_setsCurrentSession_andPostsDidStartNotification() throws {
        let notificationExpectation = expectation(forNotification: .embraceSessionPartDidStart, object: nil)

        let session = controller.startSession(state: .foreground)!
        XCTAssertNotNil(session.startTime)
        XCTAssertNotNil(controller.currentSessionSpan)
        XCTAssertEqual(controller.currentSession?.id, session.id)
        wait(for: [notificationExpectation])
    }

    func test_startSession_ifStartAtIsSoonAfterProcessStart_marksSessionAsColdStartTrue() throws {
        controller.startSession(state: .foreground, startTime: ProcessMetadata.startTime!)
        XCTAssertTrue(controller.currentSession!.coldStart)
    }

    func test_startSession_saves_foregroundSession() throws {
        let session = controller.startSession(state: .foreground)

        let sessions: [SessionRecord] = storage.fetchAll()
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.idRaw, session!.id.stringValue)
        XCTAssertEqual(sessions.first?.state, "foreground")
    }

    func test_startSession_startsSessionSpan() throws {
        let session = controller.startSession(state: .foreground)

        if let span = otel.startedSpans.first {
            XCTAssertEqual(
                span.startTime.timeIntervalSince1970,
                session!.startTime.timeIntervalSince1970,
                accuracy: 0.001
            )
            XCTAssertNil(span.endTime)
        } else {
            XCTFail("No items in `startedSpans`")
        }
    }

    func test_startSession_onlyFirstOneIsColdStart() throws {
        var session = controller.startSession(state: .foreground)
        XCTAssertTrue(session!.coldStart)

        for _ in 1...10 {
            session = controller.startSession(state: .foreground)
            XCTAssertFalse(session!.coldStart)
        }
    }

    // MARK: endSession

    func test_endSession_setsCurrentSessionToNil_andPostsWillEndNotification() throws {
        let notificationExpectation = expectation(forNotification: .embraceSessionPartWillEnd, object: nil)

        let session = controller.startSession(state: .foreground)
        XCTAssertNotNil(controller.currentSessionSpan)
        XCTAssertNil(session!.endTime)

        let endTime = controller.endSession()

        let sessions: [SessionRecord] = storage.fetchAll()
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first!.endTime!.timeIntervalSince1970, endTime.timeIntervalSince1970, accuracy: 0.1)

        XCTAssertNil(controller.currentSession)
        XCTAssertNil(controller.currentSessionSpan)

        wait(for: [notificationExpectation])
    }

    func test_endSession_foreground_writesUserSessionLastForegroundEndOnRecord() throws {
        let session = controller.startSession(state: .foreground)
        let endTime = controller.endSession()

        let stored: [SessionRecord] = storage.fetchAll()
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored.first?.idRaw, session?.id.stringValue)
        XCTAssertEqual(
            stored.first?.userSessionLastForegroundEnd?.timeIntervalSince1970 ?? 0,
            endTime.timeIntervalSince1970,
            accuracy: 0.001
        )

        // and the in-memory snapshot was updated for the next attachPart's inactivity math
        XCTAssertEqual(
            userSessionController.currentUserSession?.lastForegroundPartEnd?.timeIntervalSince1970 ?? 0,
            endTime.timeIntervalSince1970,
            accuracy: 0.001
        )
    }

    func test_endSession_background_doesNotWriteUserSessionLastForegroundEnd() throws {
        // Background-session retention requires an explicit config; the default mock keeps
        // bg parts dropped, so build a one-off controller that allows them.
        let bgConfig = EmbraceConfig(
            configurable: EditableConfig(isBackgroundSessionEnabled: true),
            options: .init(),
            notificationCenter: NotificationCenter.default,
            logger: MockLogger()
        )
        let bgController = SessionController(storage: storage, upload: nil, config: bgConfig)
        bgController.sdkStateProvider = sdkStateProvider
        bgController.otel = otel
        let bgUserSessionController = UserSessionController(
            storage: storage,
            config: MockEmbraceConfigurable()
        )
        bgUserSessionController.sessionController = bgController
        bgController.userSessionController = bgUserSessionController

        let session = bgController.startSession(state: .background)
        bgController.endSession()

        let stored: [SessionRecord] = storage.fetchAll()
        let bgRecord = stored.first { $0.idRaw == session?.id.stringValue }
        XCTAssertNotNil(bgRecord)
        XCTAssertNil(bgRecord?.userSessionLastForegroundEnd)
    }

    func test_endSessionAt_usesProvidedTimestamp() throws {
        controller.startSession(state: .foreground)
        let cutoff = Date(timeIntervalSinceNow: -120)
        controller.endSession(at: cutoff)

        let stored: [SessionRecord] = storage.fetchAll()
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(
            stored.first?.endTime?.timeIntervalSince1970 ?? 0,
            cutoff.timeIntervalSince1970,
            accuracy: 0.001
        )
    }

    func test_backfillTerminationReason_writesToLatestPart() throws {
        let session = controller.startSession(state: .foreground)
        controller.endSession()

        controller.backfillTerminationReasonOnLatestPart(.manual)

        let stored = storage.fetchSession(id: session!.id)
        XCTAssertEqual(stored?.userSessionTerminationReason, .manual)
    }

    func test_backfillTerminationReason_noStoredParts_isNoop() throws {
        // Nothing in storage — must not crash.
        controller.backfillTerminationReasonOnLatestPart(.manual)
        XCTAssertEqual((storage.fetchAll() as [SessionRecord]).count, 0)
    }

    func test_rollPartForUserSessionExpiry_endsOldStartsNewSameStateNewUserSession() throws {
        let first = controller.startSession(state: .foreground)
        let firstUserSessionId = first?.userSessionId

        let rollTime = Date()
        controller.rollPartForUserSessionExpiry(reason: .maxDurationReached, at: rollTime)

        let stored: [SessionRecord] = storage.fetchAll()
        XCTAssertEqual(stored.count, 2)

        // Old part: closed at rollTime, marked with `.maxDurationReached` via the backfill.
        let closed = stored.first { $0.idRaw == first?.id.stringValue }
        XCTAssertNotNil(closed?.endTime)
        XCTAssertEqual(closed?.userSessionTerminationReason, "max_duration_reached")

        // New part: same state, fresh user-session ID.
        XCTAssertEqual(controller.currentSession?.state, .foreground)
        XCTAssertNotEqual(controller.currentSession?.userSessionId, firstUserSessionId)
    }

    func test_rollPartForUserSessionExpiry_noActiveSession_isNoop() throws {
        controller.rollPartForUserSessionExpiry(reason: .manual, at: Date())
        XCTAssertEqual((storage.fetchAll() as [SessionRecord]).count, 0)
        XCTAssertNil(controller.currentSession)
    }

    func test_checkUserSessionMaxDurationExpiry_doubleTick_rotatesOnce() throws {
        // Two back-to-back heartbeat ticks against the same expired user session must enqueue
        // two check-then-maybe-roll blocks. The second block, when it runs, sees the state
        // left by the first (freshly-rotated user session with a far-future maxEnd) and bails.
        // Without the in-block re-check, both blocks would call rollPart and we'd see two
        // rotations.
        controller.startSession(state: .foreground)
        let userSessionStart = try XCTUnwrap(userSessionController.currentUserSession?.startTime)
        let expired = userSessionStart.addingTimeInterval(13 * 3600)  // past 12h max default

        controller.checkUserSessionMaxDurationExpiry(now: expired)
        controller.checkUserSessionMaxDurationExpiry(now: expired)

        let drained = expectation(description: "controller queue drained")
        controller.queue.async { drained.fulfill() }
        wait(for: [drained], timeout: 2)

        // One rotation: original part (closed) + new part (active). Two rotations would be 3.
        let stored: [SessionRecord] = storage.fetchAll()
        XCTAssertEqual(stored.count, 2)
        XCTAssertEqual(stored.filter { $0.endTime != nil }.count, 1)
        XCTAssertEqual(stored.filter { $0.endTime == nil }.count, 1)
    }

    func test_rollPartForUserSessionExpiry_serializedThroughQueue_producesConsistentState() throws {
        // Two back-to-back rolls dispatched onto the same serial controller queue must run
        // atomically as a unit (end-old → end-user-session → start-new). Before this queue
        // routing, heartbeat-driven and manual-driven rolls each ran on their own queues and
        // could interleave at the three sub-locks, producing a shadow part: the brand-new
        // session opened by roll A would be immediately ended by roll B's `endSession` step,
        // then re-opened, leaving a ~ms-lived part record in storage and an unbalanced
        // pair of user-session start/end notifications.
        let initial = controller.startSession(state: .foreground)

        let firstRoll = Date()
        let secondRoll = firstRoll.addingTimeInterval(0.001)

        controller.queue.async {
            self.controller.rollPartForUserSessionExpiry(reason: .maxDurationReached, at: firstRoll)
        }
        controller.queue.async {
            self.controller.rollPartForUserSessionExpiry(reason: .manual, at: secondRoll)
        }

        // Drain the controller queue.
        let drained = expectation(description: "controller queue drained")
        controller.queue.async {
            drained.fulfill()
        }
        wait(for: [drained], timeout: 2)

        // Three persisted parts (initial, post-roll-1, post-roll-2) — not four. A shadow part
        // from interleaving would inflate this count.
        let stored: [SessionRecord] = storage.fetchAll().sorted { $0.startTime < $1.startTime }
        XCTAssertEqual(stored.count, 3, "exactly one part per rotation; no shadow part")

        // The initial and the post-roll-1 parts are closed; the post-roll-2 part is active.
        XCTAssertEqual(stored.filter { $0.endTime != nil }.count, 2)
        XCTAssertEqual(stored.filter { $0.endTime == nil }.count, 1)

        // The three parts each belong to a distinct user session.
        let userSessionIds = Set(stored.compactMap { $0.userSessionIdRaw })
        XCTAssertEqual(userSessionIds.count, 3, "three distinct user sessions for three rotations")

        // The currently-active part is the one from roll 2 (last to be opened); it's a foreground
        // part because the roll preserves the state of the original part.
        XCTAssertEqual(controller.currentSession?.state, .foreground)
        XCTAssertNotEqual(controller.currentSession?.id, initial?.id)
    }

    func test_startSession_bgToFgPastUserSessionCutoff_splitsBackgroundPart() throws {
        // Build a controller whose userSessionInactivityTimeout is short so the cutoff is
        // crossed within a reasonable wall-clock window in the test. Also enable background
        // sessions so the bg part survives.
        let bgConfig = EmbraceConfig(
            configurable: EditableConfig(isBackgroundSessionEnabled: true),
            options: .init(),
            notificationCenter: NotificationCenter.default,
            logger: MockLogger()
        )
        let splitController = SessionController(storage: storage, upload: nil, config: bgConfig)
        splitController.sdkStateProvider = sdkStateProvider
        splitController.otel = otel
        // The user-session controller holds its `config` weakly; the mock must outlive this
        // scope or the controller will fall back to defaults.
        let splitConfigurable = MockEmbraceConfigurable(
            userSessionMaxDuration: 12 * 3600,
            userSessionInactivityTimeout: 1  // 1s inactivity for tight cutoff
        )
        let splitUserSessionController = UserSessionController(storage: storage, config: splitConfigurable)
        splitUserSessionController.sessionController = splitController
        splitController.userSessionController = splitUserSessionController

        // Foreground part that ends at T0 — installs the inactivity cutoff at T0+1s.
        splitController.startSession(state: .foreground)
        let foregroundEnd = splitController.endSession()
        let cutoffExpected = foregroundEnd.addingTimeInterval(1)

        // Background part that begins before the cutoff and would normally span past it.
        splitController.startSession(state: .background, startTime: foregroundEnd.addingTimeInterval(0.1))

        let bgEnd = foregroundEnd.addingTimeInterval(1.5)  // past the 1s cutoff
        // Now transition to foreground: bg-split fires.
        splitController.startSession(state: .foreground, startTime: bgEnd)

        // Three persisted parts: original fg, sliced bg [bg.start, cutoff], synthetic bg [cutoff, now],
        // and the new fg. Plus the original fg = 4 records total.
        let stored: [SessionRecord] = storage.fetchAll().sorted { $0.startTime < $1.startTime }
        XCTAssertEqual(stored.count, 4)

        // Records 2 and 3 are the split bg pair.
        let slicedBg = stored[1]
        let syntheticBg = stored[2]
        let newFg = stored[3]

        XCTAssertEqual(slicedBg.state, "background")
        XCTAssertEqual(
            slicedBg.endTime!.timeIntervalSince1970,
            cutoffExpected.timeIntervalSince1970,
            accuracy: 0.05
        )

        XCTAssertEqual(syntheticBg.state, "background")
        XCTAssertEqual(
            syntheticBg.startTime.timeIntervalSince1970,
            cutoffExpected.timeIntervalSince1970,
            accuracy: 0.05
        )

        // The synthetic bg part belongs to a NEW user session (different from the sliced bg).
        XCTAssertNotEqual(syntheticBg.userSessionIdRaw, slicedBg.userSessionIdRaw)

        // The new fg part shares the synthetic bg's user session (within bounds at this point).
        XCTAssertEqual(newFg.state, "foreground")
        XCTAssertEqual(newFg.userSessionIdRaw, syntheticBg.userSessionIdRaw)
    }

    func test_startSession_bgToFgWithinUserSessionBounds_doesNotSplit() throws {
        // Default inactivity is 30min; we'll only idle a moment, so the cutoff isn't crossed.
        let bgConfig = EmbraceConfig(
            configurable: EditableConfig(isBackgroundSessionEnabled: true),
            options: .init(),
            notificationCenter: NotificationCenter.default,
            logger: MockLogger()
        )
        let noSplitController = SessionController(storage: storage, upload: nil, config: bgConfig)
        noSplitController.sdkStateProvider = sdkStateProvider
        noSplitController.otel = otel
        let noSplitConfigurable = MockEmbraceConfigurable()  // 12h/30min defaults
        let noSplitUserSessionController = UserSessionController(storage: storage, config: noSplitConfigurable)
        noSplitUserSessionController.sessionController = noSplitController
        noSplitController.userSessionController = noSplitUserSessionController

        noSplitController.startSession(state: .foreground)
        noSplitController.endSession()
        let bgFirst = noSplitController.startSession(state: .background)
        noSplitController.startSession(state: .foreground)

        // No split: only the original fg, the bg, and the new fg — three records total.
        let stored: [SessionRecord] = storage.fetchAll()
        XCTAssertEqual(stored.count, 3)

        // The bg part is closed cleanly (no synthetic split) — its user session matches the
        // following foreground part.
        let bgRecord = stored.first { $0.idRaw == bgFirst?.id.stringValue }
        XCTAssertNotNil(bgRecord?.endTime)
    }

    func test_endSession_saves_foregroundSession() throws {
        let session = controller.startSession(state: .foreground)
        XCTAssertNil(session!.endTime)

        let endTime = controller.endSession()

        let sessions: [SessionRecord] = storage.fetchAll()
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first!.idRaw, session!.id.stringValue)
        XCTAssertEqual(sessions.first!.state, "foreground")
        XCTAssertEqual(sessions.first!.endTime!.timeIntervalSince1970, endTime.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(sessions.first!.cleanExit, true)
    }

    func test_endSession_updatesLocalSessionBeforeUploading() throws {
        // given a started session
        let otel = MockOTelSignalsHandler()
        let uploader = MockSessionUploader()
        let controller = SessionController(storage: storage, upload: upload, uploader: uploader, config: nil)
        controller.sdkStateProvider = sdkStateProvider
        controller.otel = otel
        controller.startSession(state: .foreground)

        // when ending the session
        controller.endSession()

        let expectation = expectation(description: "waiting for session to end")
        controller.queue.async {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: .defaultTimeout)

        // then a session was sent with the corrent values
        XCTAssert(uploader.didCallUploadSession)
        XCTAssertNotNil(uploader.uploadedSession)
        XCTAssertNotNil(uploader.uploadedSession!.endTime)
        XCTAssert(uploader.uploadedSession!.cleanExit)
    }

    func test_endSession_saves_endsSessionSpan() throws {
        controller.startSession(state: .foreground)
        let endTime = controller.endSession()

        if let span = otel.endedSpans.first {
            XCTAssertEqual(span.endTime!.timeIntervalSince1970, endTime.timeIntervalSince1970, accuracy: 0.001)
        }
    }

    func wait(_ until: @escaping () -> Bool) {
        // Here, we end up having to wait for the DefaultSession uploader which
        // isn't set up to give us a completion, so we'll fake it 'till we make it.
        wait(timeout: 2, interval: 0.01) {
            until()
        }
    }

    // This test is crazy on the waiting,
    // but  I want to wait as little time as possible without
    // a full refactor that actually allows us to get
    // completion on sessions.
    @MainActor
    func test_endSession_uploadsSession() throws {
        try XCTSkipIfRunMoreThanOnce()
        try XCTSkipIf(XCTestCase.isWatchOS(), "Unavailable on WatchOS")
        // mock successful requests
        EmbraceHTTPMock.mock(url: testSessionsUrl())

        // given a started session
        let controller = SessionController(storage: storage, upload: upload, config: nil)
        controller.sdkStateProvider = sdkStateProvider
        controller.otel = otel
        controller.startSession(state: .foreground)

        // when ending the session
        controller.endSession()

        let expectation = expectation(description: "waiting for session to end")
        // we need to wait for the controller to async send it data,
        // as well as storgage (CoreData) to update the session info.
        // we don't have a better async way than to tack onto their queue's,
        // and just run a block at the end.
        storage.coreData.performAsyncOperation { _ in
            controller.queue.async { [self] in
                storage.coreData.performAsyncOperation { _ in
                    controller.queue.async { [self] in
                        upload.queue.async {
                            expectation.fulfill()
                        }
                    }
                }
            }
        }
        wait(for: [expectation], timeout: .longTimeout)
        wait { EmbraceHTTPMock.requestsForUrl(self.testSessionsUrl()).count == 1 }

        // then a session request was sent
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(testSessionsUrl()).count, 1)

        // then the session is no longer on storage
        let session = storage.fetchSession(id: TestConstants.sessionId)
        XCTAssertNil(session)

        // then the session upload data is no longer cached
        wait { [self] in
            let uploadData = upload.cache.fetchAllUploadData()
            return uploadData.isEmpty
        }
        let uploadData = upload.cache.fetchAllUploadData()
        XCTAssertEqual(uploadData.count, 0)
    }

    func test_endSession_uploadsSession_error() throws {
        try XCTSkipIf(XCTestCase.isWatchOS(), "Unavailable on WatchOS")
        // mock error requests
        EmbraceHTTPMock.mock(url: testSessionsUrl(), errorCode: 500)

        // given a started session
        let controller = SessionController(storage: storage, upload: upload, config: nil)
        controller.sdkStateProvider = sdkStateProvider
        controller.otel = otel
        controller.startSession(state: .foreground)

        // when ending the session and the upload fails
        controller.endSession()
        wait { EmbraceHTTPMock.requestsForUrl(self.testSessionsUrl()).count > 0 }

        // then a session request was attempted
        XCTAssertGreaterThan(EmbraceHTTPMock.requestsForUrl(testSessionsUrl()).count, 0)

        // then the total amount of requests is correct
        XCTAssertEqual(EmbraceHTTPMock.totalRequestCount(), 1)

        // then the session is no longer on storage
        let session = storage.fetchSession(id: TestConstants.sessionId)
        XCTAssertNil(session)

        // then the session upload data cached
        let uploadData = upload.cache.fetchAllUploadData()
        XCTAssertEqual(uploadData.count, 1)
    }

    // MARK: update

    func test_update_assignsState_toBackground_whenPresent() throws {
        controller.startSession(state: .foreground)
        XCTAssertEqual(controller.currentSession?.state, .foreground)

        controller.update(state: .background)
        XCTAssertEqual(controller.currentSession?.state, .background)
    }

    func test_update_assignsAppTerminated_toFalse_whenPresent() throws {
        controller.startSession(state: .foreground)

        controller.update(appTerminated: false)
        XCTAssertEqual(controller.currentSession?.appTerminated, false)
    }

    func test_update_assignsAppTerminated_toTrue_whenPresent() throws {
        controller.startSession(state: .foreground)

        controller.update(appTerminated: true)
        XCTAssertEqual(controller.currentSession?.appTerminated, true)
    }

    func test_update_changesTo_appTerminated_saveInStorage() throws {
        let session = controller.startSession(state: .foreground)

        controller.update(appTerminated: true)

        let sessions: [SessionRecord] = storage.fetchAll()
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.idRaw, session!.id.stringValue)
        XCTAssertEqual(sessions.first?.state, "foreground")
        XCTAssertEqual(sessions.first?.appTerminated, true)
    }

    func test_update_changesTo_sessionState_saveInStorage() throws {
        let session = controller.startSession(state: .foreground)

        controller.update(state: .background)

        let sessions: [SessionRecord] = storage.fetchAll()
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.idRaw, session!.id.stringValue)
        XCTAssertEqual(sessions.first?.state, "background")
        XCTAssertEqual(sessions.first?.appTerminated, false)
    }

    // MARK: background
    func test_startup_background_enabled() throws {

        // given background sessions enabled
        try mockSuccessfulResponse()

        let configUrlSessionconfig = URLSessionConfiguration.ephemeral
        configUrlSessionconfig.httpMaximumConnectionsPerHost = .max
        configUrlSessionconfig.protocolClasses = [EmbraceHTTPMock.self]

        let config = EmbraceConfig(
            configurable: EditableConfig(isBackgroundSessionEnabled: true),
            options: .init(),
            notificationCenter: NotificationCenter.default, logger: MockLogger()
        )

        let controller = SessionController(
            storage: storage,
            upload: nil,
            config: config
        )
        controller.sdkStateProvider = sdkStateProvider
        controller.otel = otel

        // when starting a cold start session in the background
        let session = controller.startSession(state: .background)

        // then the session is created
        XCTAssertNotNil(session)

        // when the session ends
        controller.endSession()

        // then the session is stored
        let sessions: [SessionRecord] = storage.fetchAll()
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.idRaw, session!.id.stringValue)
        XCTAssertEqual(sessions.first?.state, "background")
    }

    func mockSuccessfulResponse() throws {
        var url = try XCTUnwrap(URL(string: "\(configBaseUrl)/v2/config"))

        if #available(iOS 16.0, watchOS 9.0, tvOS 16.0, *) {
            url.append(queryItems: [
                .init(name: "appId", value: TestConstants.appId),
                .init(name: "osVersion", value: TestConstants.osVersion),
                .init(name: "appVersion", value: TestConstants.appVersion),
                .init(name: "sdkVersion", value: TestConstants.sdkVersion)
            ])
        } else {
            XCTFail("This will fail on versions prior to iOS 16.0")
        }

        let path = Bundle.module.path(
            forResource: "remote_config_background_enabled",
            ofType: "json",
            inDirectory: "Mocks"
        )!
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        EmbraceHTTPMock.mock(url: url, response: .withData(data, statusCode: 200))
    }

    func test_startup_background_disabled() throws {

        // given background sessions disabled
        let controller = SessionController(
            storage: storage,
            upload: nil,
            config: nil
        )
        controller.sdkStateProvider = sdkStateProvider
        controller.otel = otel

        // when starting a cold start session in the background
        let session = controller.startSession(state: .background)

        // then the session is created
        XCTAssertNotNil(session)

        // when the session ends
        controller.endSession()

        // then the session is not stored
        let sessions: [SessionRecord] = storage.fetchAll()
        XCTAssertEqual(sessions.count, 0)
    }

    // MARK: heartbeat

    func test_startSession_assignsSessionPartNumber() throws {
        // when starting a session
        let session = controller.startSession(state: .foreground)

        // then sessionNumber == 1 and the permanent counter is at 1
        XCTAssertEqual(session?.sessionNumber, 1)
        let resource = storage.fetchRequiredPermanentResource(key: SessionController.sessionPartNumberKey)
        XCTAssertEqual(resource?.value, "1")
    }

    func test_startSession_incrementsSessionPartNumberPerPart() throws {
        // given two parts under the same user session
        let first = controller.startSession(state: .foreground)
        controller.endSession()
        let second = controller.startSession(state: .foreground)

        // then each part has a unique, strictly-increasing sessionNumber
        XCTAssertEqual(first?.sessionNumber, 1)
        XCTAssertEqual(second?.sessionNumber, 2)
        let resource = storage.fetchRequiredPermanentResource(key: SessionController.sessionPartNumberKey)
        XCTAssertEqual(resource?.value, "2")
    }

    func test_startSession_continuesFromExistingCounter() throws {
        // given an existing counter value of 5
        storage.addMetadata(
            key: SessionController.sessionPartNumberKey,
            value: "5",
            type: .requiredResource,
            lifespan: .permanent
        )

        // when starting a session, the per-part counter continues from 6
        let session = controller.startSession(state: .foreground)

        XCTAssertEqual(session?.sessionNumber, 6)

        let resource = storage.fetchRequiredPermanentResource(key: SessionController.sessionPartNumberKey)
        XCTAssertEqual(resource?.value, "6")
    }

    func test_startSession_persistsUserSessionColumnsOnRecord() throws {
        let session = controller.startSession(state: .foreground)
        XCTAssertNotNil(session)

        let stored: [SessionRecord] = storage.fetchAll()
        XCTAssertEqual(stored.count, 1)
        let record = stored[0]
        XCTAssertNotNil(record.userSessionIdRaw)
        XCTAssertNotNil(record.userSessionStartTime)
        XCTAssertEqual(record.userSessionMaxDuration?.doubleValue, configurable.userSessionMaxDuration)
        XCTAssertEqual(record.userSessionInactivityTimeout?.doubleValue, configurable.userSessionInactivityTimeout)
        XCTAssertEqual(record.userSessionPartIndex, 1)
    }

    func test_startSession_backgroundPartIncrementsSessionNumber() throws {
        // `sessionNumber` is the global per-part counter and must bump regardless of state.
        let bgConfig = EmbraceConfig(
            configurable: EditableConfig(isBackgroundSessionEnabled: true),
            options: .init(),
            notificationCenter: NotificationCenter.default,
            logger: MockLogger()
        )
        let bgController = SessionController(storage: storage, upload: nil, config: bgConfig)
        bgController.sdkStateProvider = sdkStateProvider
        bgController.otel = otel
        let bgUserSessionController = UserSessionController(storage: storage, config: MockEmbraceConfigurable())
        bgUserSessionController.sessionController = bgController
        bgController.userSessionController = bgUserSessionController

        let bg = bgController.startSession(state: .background)
        XCTAssertEqual(bg?.sessionNumber, 1)
        let resource = storage.fetchRequiredPermanentResource(key: SessionController.sessionPartNumberKey)
        XCTAssertEqual(resource?.value, "1")
    }

    func test_sessionNumberAndPartIndex_independentAcrossUserSessionRollover() throws {
        // After a user-session rollover, `userSessionPartIndex` resets to 1 while the global
        // `sessionNumber` keeps incrementing. The two counters are independent.
        controller.startSession(state: .foreground)
        controller.endSession()
        controller.startSession(state: .foreground)

        // Force a user-session rollover.
        controller.rollPartForUserSessionExpiry(reason: .maxDurationReached, at: Date())

        let stored: [SessionRecord] = storage.fetchAll().sorted { $0.sessionNumber < $1.sessionNumber }
        XCTAssertEqual(stored.count, 3)
        XCTAssertEqual(stored.map { $0.sessionNumber }, [1, 2, 3], "sessionNumber strictly increasing across rollover")
        XCTAssertEqual(stored[0].userSessionPartIndex, 1)
        XCTAssertEqual(stored[1].userSessionPartIndex, 2)
        XCTAssertEqual(stored[2].userSessionPartIndex, 1, "partIndex resets to 1 in the new user session")

        // First two parts belong to the same user session; the third is a new one.
        XCTAssertEqual(stored[0].userSessionIdRaw, stored[1].userSessionIdRaw)
        XCTAssertNotEqual(stored[1].userSessionIdRaw, stored[2].userSessionIdRaw)
    }

    func test_partsOfSameUserSession_shareUserSessionFields() throws {
        // Parts 1, 2, 3 of one user session share id/startTime/maxDuration/inactivityTimeout;
        // only partIndex differs.
        controller.startSession(state: .foreground)
        controller.endSession()
        controller.startSession(state: .foreground)
        controller.endSession()
        controller.startSession(state: .foreground)

        let stored: [SessionRecord] = storage.fetchAll().sorted { $0.sessionNumber < $1.sessionNumber }
        XCTAssertEqual(stored.count, 3)

        let firstId = stored[0].userSessionIdRaw
        let firstStart = stored[0].userSessionStartTime
        let firstMax = stored[0].userSessionMaxDuration
        let firstInactivity = stored[0].userSessionInactivityTimeout

        for record in stored {
            XCTAssertEqual(record.userSessionIdRaw, firstId)
            XCTAssertEqual(record.userSessionStartTime, firstStart)
            XCTAssertEqual(record.userSessionMaxDuration, firstMax)
            XCTAssertEqual(record.userSessionInactivityTimeout, firstInactivity)
        }

        XCTAssertEqual(stored.map { $0.userSessionPartIndex }, [1, 2, 3])
    }

    func test_heartbeat() throws {
        // given a session controller
        let controller = SessionController(storage: storage, upload: nil, config: nil, heartbeatInterval: 0.1)
        controller.sdkStateProvider = sdkStateProvider
        controller.otel = otel

        // when starting a session
        let session = controller.startSession(state: .foreground)
        var lastDate = session!.lastHeartbeatTime

        // then the heartbeat time is updated
        for _ in 1...3 {
            wait(delay: 0.3)
            XCTAssertNotEqual(lastDate, controller.currentSession!.lastHeartbeatTime)
            lastDate = controller.currentSession!.lastHeartbeatTime
        }
    }
}

extension SessionControllerTests {
    fileprivate func testEndpointOptions(testName: String) -> EmbraceUpload.EndpointOptions {
        .init(
            spansURL: testSessionsUrl(testName: testName),
            logsURL: testLogsUrl(testName: testName),
            attachmentsURL: testAttachmentsUrl(testName: testName)
        )
    }

    fileprivate func testSessionsUrl(testName: String = #function) -> URL {
        URL(string: "https://embrace.\(testName).com/session_controller/sessions")!
    }

    fileprivate func testLogsUrl(testName: String = #function) -> URL {
        URL(string: "https://embrace.\(testName).com/session_controller/logs")!
    }

    fileprivate func testAttachmentsUrl(testName: String = #function) -> URL {
        URL(string: "https://embrace.\(testName).com/session_controller/attachments")!
    }

    private var configBaseUrl: String {
        "https://embrace.\(testName).com/config"
    }
}
