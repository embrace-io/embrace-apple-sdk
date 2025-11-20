//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceConfigInternal
import EmbraceOTelInternal
import EmbraceStorageInternal
import TestSupport
import XCTest

@testable import EmbraceCore
@testable import EmbraceUploadInternal

final class SessionControllerTests: XCTestCase {

    var storage: EmbraceStorage!
    var controller: SessionController!
    var config: EmbraceConfig!
    var upload: EmbraceUpload!
    let sdkStateProvider = MockEmbraceSDKStateProvider()

    static let testMetadataOptions = EmbraceUpload.MetadataOptions(
        apiKey: "apiKey",
        userAgent: "userAgent",
        deviceId: "12345678"
    )
    static let testRedundancyOptions = EmbraceUpload.RedundancyOptions(automaticRetryCount: 0)

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

        // we pass nil so we only use the upload/config module in the relevant tests
        controller = SessionController(storage: storage, upload: nil, config: nil)
        controller.sdkStateProvider = sdkStateProvider
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
        XCTAssertEqual(a!.state, "foreground")
    }

    // MARK: startSession

    func test_startSession_setsCurrentSession_andPostsDidStartNotification() throws {
        let notificationExpectation = expectation(forNotification: .embraceSessionDidStart, object: nil)

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
        XCTAssertEqual(sessions.first?.idRaw, session!.idRaw)
        XCTAssertEqual(sessions.first?.state, "foreground")
    }

    func test_startSession_startsSessionSpan() throws {
        let spanProcessor = MockSpanProcessor()
        EmbraceOTel.setup(spanProcessors: [spanProcessor])

        let session = controller.startSession(state: .foreground)

        if let spanData = spanProcessor.startedSpans.first {
            XCTAssertEqual(
                spanData.startTime.timeIntervalSince1970,
                session!.startTime.timeIntervalSince1970,
                accuracy: 0.001
            )
            XCTAssertFalse(spanData.hasEnded)
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
        let notificationExpectation = expectation(forNotification: .embraceSessionWillEnd, object: nil)

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

    func test_endSession_saves_foregroundSession() throws {
        let session = controller.startSession(state: .foreground)
        XCTAssertNil(session!.endTime)

        let endTime = controller.endSession()

        let sessions: [SessionRecord] = storage.fetchAll()
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first!.idRaw, session!.idRaw)
        XCTAssertEqual(sessions.first!.state, "foreground")
        XCTAssertEqual(sessions.first!.endTime!.timeIntervalSince1970, endTime.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(sessions.first!.cleanExit, true)
    }

    func test_endSession_updatesLocalSessionBeforeUploading() throws {
        // given a started session
        let uploader = MockSessionUploader()
        let controller = SessionController(storage: storage, upload: upload, uploader: uploader, config: nil)
        controller.sdkStateProvider = sdkStateProvider
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
        let spanProcessor = MockSpanProcessor()
        EmbraceOTel.setup(spanProcessors: [spanProcessor])

        controller.startSession(state: .foreground)
        let endTime = controller.endSession()

        if let spanData = spanProcessor.endedSpans.first {
            XCTAssertEqual(spanData.endTime.timeIntervalSince1970, endTime.timeIntervalSince1970, accuracy: 0.001)
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

    func testOnHavingBatcher_endSession_forcesEndBatchAndWaits() throws {
        // given sesion controller has a batcher
        let batcher = SpyLogBatcher()
        controller.setLogBatcher(batcher)

        // given a session was started
        controller.startSession(state: .foreground)

        // when ending the session
        controller.endSession()

        // then should force end current batch
        XCTAssertTrue(batcher.didCallForceEndCurrentBatch)

        // then should wait for log batch to be closed
        XCTAssertTrue(try XCTUnwrap(batcher.forceEndCurrentBatchParameters))
    }

    // MARK: update

    func test_update_assignsState_toBackground_whenPresent() throws {
        controller.startSession(state: .foreground)
        XCTAssertEqual(controller.currentSession?.state, "foreground")

        controller.update(state: .background)
        XCTAssertEqual(controller.currentSession?.state, "background")
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
        XCTAssertEqual(sessions.first?.idRaw, session!.idRaw)
        XCTAssertEqual(sessions.first?.state, "foreground")
        XCTAssertEqual(sessions.first?.appTerminated, true)
    }

    func test_update_changesTo_sessionState_saveInStorage() throws {
        let session = controller.startSession(state: .foreground)

        controller.update(state: .background)

        let sessions: [SessionRecord] = storage.fetchAll()
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.idRaw, session!.idRaw)
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

        // when starting a cold start session in the background
        let session = controller.startSession(state: .background)

        // then the session is created
        XCTAssertNotNil(session)

        // when the session ends
        controller.endSession()

        // then the session is stored
        let sessions: [SessionRecord] = storage.fetchAll()
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.idRaw, session!.idRaw)
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

    func test_heartbeat() throws {
        // given a session controller
        let controller = SessionController(storage: storage, upload: nil, config: nil, heartbeatInterval: 0.1)
        controller.sdkStateProvider = sdkStateProvider

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

    func test_heartbeat_runsOnMainThread() throws {
        // given a session controller with fast heartbeat
        var heartbeatThread: Thread?
        let controller = SessionController(storage: storage, upload: nil, config: nil, heartbeatInterval: 0.05)
        controller.sdkStateProvider = sdkStateProvider

        // when starting a session
        controller.startSession(state: .foreground)

        // then wait for heartbeat to fire
        wait(delay: 0.2)

        // then capture thread during heartbeat update
        let expectation = expectation(description: "heartbeat fires")
        controller.heartbeat.callback = {
            heartbeatThread = Thread.current
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)

        // then verify heartbeat ran on main thread
        XCTAssertTrue(heartbeatThread?.isMainThread ?? false, "Heartbeat should run on main thread")
    }

    func test_heartbeat_doesNotCauseThreadingIssuesDuringRapidSessionTransitions() throws {
        // given a session controller with very fast heartbeat
        let controller = SessionController(
            storage: storage,
            upload: nil,
            config: nil,
            heartbeatInterval: 0.02
        )
        controller.sdkStateProvider = sdkStateProvider

        // when starting session (starts heartbeat)
        controller.startSession(state: .foreground)

        // when rapidly transitioning sessions while heartbeat is running
        for _ in 0..<20 {
            wait(delay: 0.01)
            controller.startSession(state: .foreground)
        }

        // then no crashes occurred and we have a valid session
        XCTAssertNotNil(controller.currentSession)
    }

    // MARK: notification timing

    func test_startSession_notificationFiresAfterSessionStateIsSet() throws {
        var notificationSession: EmbraceSession?
        var controllerSessionAtNotificationTime: EmbraceSession?

        let observer = NotificationCenter.default.addObserver(
            forName: .embraceSessionDidStart,
            object: nil,
            queue: nil
        ) { notification in
            notificationSession = notification.object as? EmbraceSession
            controllerSessionAtNotificationTime = self.controller.currentSession
        }

        defer { NotificationCenter.default.removeObserver(observer) }

        let session = controller.startSession(state: .foreground)

        // then notification received correct session
        XCTAssertEqual(notificationSession?.id, session?.id)
        // then controller state was already updated when notification fired
        XCTAssertEqual(controllerSessionAtNotificationTime?.id, session?.id)
    }

    func test_endSession_notificationFiresBeforeSessionCleared() throws {
        var sessionAtNotificationTime: EmbraceSession?
        var controllerSessionDuringWillEnd: EmbraceSession?

        controller.startSession(state: .foreground)
        let originalSession = controller.currentSession

        let observer = NotificationCenter.default.addObserver(
            forName: .embraceSessionWillEnd,
            object: nil,
            queue: nil
        ) { notification in
            sessionAtNotificationTime = notification.object as? EmbraceSession
            // Controller should still have session when willEnd fires
            controllerSessionDuringWillEnd = self.controller.currentSession
        }

        defer { NotificationCenter.default.removeObserver(observer) }

        controller.endSession()

        // then notification received correct session
        XCTAssertEqual(sessionAtNotificationTime?.id, originalSession?.id)
        // then controller still had session during willEnd notification
        XCTAssertEqual(controllerSessionDuringWillEnd?.id, originalSession?.id)
        // then controller session is now cleared after endSession completes
        XCTAssertNil(controller.currentSession)
    }

    // MARK: firstSession thread safety

    func test_firstSession_coldStart_subsequentSessionsNotColdStart() throws {
        // when starting first session
        let session1 = controller.startSession(state: .foreground)

        // then first session should be cold start
        XCTAssertTrue(session1!.coldStart)

        // when starting subsequent sessions
        for i in 1...10 {
            let session = controller.startSession(state: .foreground)
            // then they should not be cold start
            XCTAssertFalse(session!.coldStart, "Session \(i) should not be cold start")
        }
    }

    func test_rapidSessionTransitions_maintainsFirstSessionFlag() throws {
        // when starting and ending sessions rapidly
        for i in 0..<100 {
            let session = controller.startSession(state: .foreground)

            if i == 0 {
                // then first session should be cold start
                XCTAssertTrue(session!.coldStart, "First session should be cold start")
            } else {
                // then subsequent sessions should not be cold start
                XCTAssertFalse(session!.coldStart, "Session \(i) should not be cold start")
            }

            // end some sessions to test varied patterns
            if i % 2 == 0 {
                controller.endSession()
            }
        }
    }

    // MARK: session transition atomicity

    func test_startSession_endsCurrentSession_thenStartsNew() throws {
        // given first session
        let session1 = controller.startSession(state: .foreground)!
        let session1Id = session1.id

        // when starting second session (should end first, then start second)
        let session2 = controller.startSession(state: .foreground)!
        let session2Id = session2.id

        // then they're different sessions
        XCTAssertNotEqual(session1Id, session2Id)

        // then controller has new session
        XCTAssertEqual(controller.currentSession?.id, session2Id)

        // then first session was ended in storage
        let endedSession1 = storage.fetchSession(id: session1Id!)
        XCTAssertNotNil(endedSession1?.endTime)
    }

    func test_startSession_whenPreviousSessionExists_oldSessionAccessibleDuringWillEndNotification() throws {
        var sessionsDuringWillEnd: [EmbraceSession?] = []

        // given observer tracking session state during transition
        let observer = NotificationCenter.default.addObserver(
            forName: .embraceSessionWillEnd,
            object: nil,
            queue: nil
        ) { _ in
            // during willEnd, should still have old session accessible
            sessionsDuringWillEnd.append(self.controller.currentSession)
        }

        defer { NotificationCenter.default.removeObserver(observer) }

        // when starting first session
        let session1 = controller.startSession(state: .foreground)

        // when starting second session (triggers willEnd for first)
        let session2 = controller.startSession(state: .foreground)

        // then old session was accessible during willEnd notification
        XCTAssertEqual(sessionsDuringWillEnd.count, 1)
        XCTAssertEqual(sessionsDuringWillEnd[0]?.id, session1!.id)

        // then new session is now current
        XCTAssertEqual(controller.currentSession?.id, session2!.id)
    }

    // MARK: background session with cold start

    func test_coldStartBackgroundSession_transitionsToForeground_notDropped() throws {
        // given background sessions disabled
        let controller = SessionController(
            storage: storage,
            upload: nil,
            config: nil
        )
        controller.sdkStateProvider = sdkStateProvider

        // when starting cold start session in background
        let session = controller.startSession(state: .background)

        // then session is created
        XCTAssertNotNil(session)
        XCTAssertTrue(session!.coldStart)
        XCTAssertEqual(session!.state, "background")

        // when updating to foreground (simulating grace period transition)
        controller.update(state: .foreground)

        // when session ends
        controller.endSession()

        // then the session is stored (not dropped because it transitioned to foreground)
        let sessions: [SessionRecord] = storage.fetchAll()
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.state, "foreground")
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
