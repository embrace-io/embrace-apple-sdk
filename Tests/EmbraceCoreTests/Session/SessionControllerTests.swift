//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceCore
import EmbraceStorageInternal
@testable import EmbraceUploadInternal
import EmbraceCommonInternal
import EmbraceOTelInternal
import EmbraceConfigInternal
import TestSupport

final class SessionControllerTests: XCTestCase {

    var storage: EmbraceStorage!
    var controller: SessionController!
    var upload: EmbraceUpload!

    static let testMetadataOptions = EmbraceUpload.MetadataOptions(
        apiKey: "apiKey",
        userAgent: "userAgent",
        deviceId: "12345678"
    )
    static let testRedundancyOptions = EmbraceUpload.RedundancyOptions(automaticRetryCount: 0)

    var uploadTestOptions: EmbraceUpload.Options!

    var queue: DispatchQueue!
    var module: EmbraceUpload!

    override func setUpWithError() throws {
        let uploadUrlSessionconfig = URLSessionConfiguration.ephemeral
        uploadUrlSessionconfig.httpMaximumConnectionsPerHost = .max
        uploadUrlSessionconfig.protocolClasses = [EmbraceHTTPMock.self]

        uploadTestOptions = EmbraceUpload.Options(
            endpoints: testEndpointOptions(testName: testName),
            cache: EmbraceUpload.CacheOptions(named: testName),
            metadata: Self.testMetadataOptions,
            redundancy: Self.testRedundancyOptions,
            urlSessionConfiguration: uploadUrlSessionconfig
        )

        self.queue = DispatchQueue(label: "com.test.embrace.upload.queue", attributes: .concurrent)
        upload = try EmbraceUpload(options: uploadTestOptions, logger: MockLogger(), queue: queue)
        storage = try EmbraceStorage.createInMemoryDb()

        // we pass nil so we only use the upload/config module in the relevant tests
        controller = SessionController(storage: storage, upload: nil, config: nil)
    }

    override func tearDownWithError() throws {
        try storage.teardown()
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

        let sessions: [SessionRecord] = try storage.fetchAll()
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.id, session!.id)
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

        let sessions: [SessionRecord] = try storage.fetchAll()
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

        let sessions: [SessionRecord] = try storage.fetchAll()
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first!.id, session!.id)
        XCTAssertEqual(sessions.first!.state, "foreground")
        XCTAssertEqual(sessions.first!.endTime!.timeIntervalSince1970, endTime.timeIntervalSince1970, accuracy: 0.001)
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

    func test_endSession_uploadsSession() throws {
        // mock successful requests
        EmbraceHTTPMock.mock(url: testSessionsUrl())

        // given a started session
        let controller = SessionController(storage: storage, upload: upload, config: nil)
        controller.startSession(state: .foreground)

        // when ending the session
        controller.endSession()
        wait(delay: .longTimeout)

        // then a session request was sent
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(testSessionsUrl()).count, 1)

        // then the session is no longer on storage
        let session = try storage.fetchSession(id: TestConstants.sessionId)
        XCTAssertNil(session)

        // then the session upload data is no longer cached
        let uploadData = try upload.cache.fetchAllUploadData()
        XCTAssertEqual(uploadData.count, 0)
    }

    func test_endSession_uploadsSession_error() throws {
        // mock error requests
        EmbraceHTTPMock.mock(url: testSessionsUrl(), errorCode: 500)

        // given a started session
        let controller = SessionController(storage: storage, upload: upload, config: nil)
        controller.startSession(state: .foreground)

        // when ending the session and the upload fails
        controller.endSession()
        wait(delay: .longTimeout)

        // then a session request was attempted
        XCTAssertGreaterThan(EmbraceHTTPMock.requestsForUrl(testSessionsUrl()).count, 0)

        // then the total amount of requests is correct
        XCTAssertEqual(EmbraceHTTPMock.totalRequestCount(), 1)

        // then the session is no longer on storage
        let session = try storage.fetchSession(id: TestConstants.sessionId)
        XCTAssertNil(session)

        // then the session upload data cached
        let uploadData = try upload.cache.fetchAllUploadData()
        XCTAssertEqual(uploadData.count, 1)
    }

    // MARK: update

    func test_update_assignsState_toBackground_whenPresent() throws {
        controller.startSession(state: .foreground)
        XCTAssertEqual(controller.currentSession?.state, "foreground")

        controller.update(state: .background)
        XCTAssertEqual(controller.currentSession?.state, "background")
    }

    func test_update_assignsAppTerminated_toFalse_whenPresent() throws {
        var session = controller.startSession(state: .foreground)
        session!.appTerminated = true

        controller.update(appTerminated: false)
        XCTAssertEqual(controller.currentSession?.appTerminated, false)
    }

    func test_update_assignsAppTerminated_toTrue_whenPresent() throws {
        var session = controller.startSession(state: .foreground)
        session!.appTerminated = false

        controller.update(appTerminated: true)
        XCTAssertEqual(controller.currentSession?.appTerminated, true)
    }

    func test_update_changesTo_appTerminated_saveInStorage() throws {
        var session = controller.startSession(state: .foreground)
        session!.appTerminated = false

        controller.update(appTerminated: true)

        let sessions: [SessionRecord] = try storage.fetchAll()
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.id, session!.id)
        XCTAssertEqual(sessions.first?.state, "foreground")
        XCTAssertEqual(sessions.first?.appTerminated, true)
    }

    func test_update_changesTo_sessionState_saveInStorage() throws {
        var session = controller.startSession(state: .foreground)
        session!.appTerminated = false

        controller.update(state: .background)

        let sessions: [SessionRecord] = try storage.fetchAll()
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.id, session!.id)
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

        let configTestOptions = EmbraceConfig.Options(
            apiBaseUrl: configBaseUrl,
            queue: DispatchQueue(label: "com.test.embrace.config.queue", attributes: .concurrent),
            appId: TestConstants.appId,
            deviceId: TestConstants.deviceId,
            osVersion: TestConstants.osVersion,
            sdkVersion: TestConstants.sdkVersion,
            appVersion: TestConstants.appVersion,
            userAgent: TestConstants.userAgent,
            urlSessionConfiguration: configUrlSessionconfig
        )

        let config = EmbraceConfig(
            options: configTestOptions,
            notificationCenter: NotificationCenter.default,
            logger: MockLogger()
        )
        wait(delay: .defaultTimeout)

        let controller = SessionController(
            storage: storage,
            upload: nil,
            config: config
        )

        // when starting a cold start session in the background
        let session = controller.startSession(state: .background)

        // then the session is created
        XCTAssertNotNil(session)

        // when the session ends
        controller.endSession()

        // then the session is stored
        let sessions: [SessionRecord] = try storage.fetchAll()
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.id, session!.id)
        XCTAssertEqual(sessions.first?.state, "background")
    }

    func mockSuccessfulResponse() throws {
        var url = try XCTUnwrap(URL(string: "\(configBaseUrl)/v2/config"))

        if #available(iOS 16.0, *) {
            url.append(queryItems: [
                .init(name: "appId", value: TestConstants.appId),
                .init(name: "osVersion", value: TestConstants.osVersion),
                .init(name: "appVersion", value: TestConstants.appVersion),
                .init(name: "deviceId", value: TestConstants.deviceId),
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

        // when starting a cold start session in the background
        let session = controller.startSession(state: .background)

        // then the session is created
        XCTAssertNotNil(session)

        // when the session ends
        controller.endSession()

        // then the session is not stored
        let sessions: [SessionRecord] = try storage.fetchAll()
        XCTAssertEqual(sessions.count, 0)
    }

    // MARK: heartbeat

    func test_heartbeat() throws {
        // given a session controller with a 1 second heartbeat invertal
        let controller = SessionController(storage: storage, upload: nil, config: nil, heartbeatInterval: 1)

        // when starting a session
        let session = controller.startSession(state: .foreground)
        var lastDate = session!.lastHeartbeatTime

        // then the heartbeat time is updated every second
        for _ in 1...3 {
            wait(delay: 1)
            XCTAssertNotEqual(lastDate, controller.currentSession!.lastHeartbeatTime)
            lastDate = controller.currentSession!.lastHeartbeatTime
        }
    }
}

private extension SessionControllerTests {
    func testEndpointOptions(testName: String) -> EmbraceUpload.EndpointOptions {
        .init(
            spansURL: testSessionsUrl(testName: testName),
            logsURL: testLogsUrl(testName: testName)
        )
    }

    func testSessionsUrl(testName: String = #function) -> URL {
        URL(string: "https://embrace.\(testName).com/session_controller/sessions")!
    }

    func testLogsUrl(testName: String = #function) -> URL {
        URL(string: "https://embrace.\(testName).com/session_controller/logs")!
    }

    private var configBaseUrl: String {
        "https://embrace.\(testName).com/config"
    }
}
