//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceSemantics
import Foundation
import TestSupport
import XCTest

@testable import EmbraceCore
@testable import EmbraceStorageInternal
@testable import EmbraceUploadInternal

class UnsentDataHandlerTests: XCTestCase {
    let logger = MockLogger()
    let filePathProvider = TemporaryFilepathProvider()
    var context: CrashReporterContext!
    var uploadOptions: EmbraceUpload.Options!
    var queue: DispatchQueue!
    let sdkStateProvider = MockEmbraceSDKStateProvider()
    var criticalLogsFilePath: URL!

    static let testRedundancyOptions = EmbraceUpload.RedundancyOptions(automaticRetryCount: -1)
    static let testMetadataOptions = EmbraceUpload.MetadataOptions(
        apiKey: "apiKey",
        userAgent: "userAgent",
        deviceId: "12345678"
    )

    override func setUpWithError() throws {
        // delete tmpdir
        try? FileManager.default.removeItem(at: filePathProvider.tmpDirectory)

        criticalLogsFilePath = filePathProvider.fileURL(for: "UnsentDataHandlerTests", name: "file")
        try? FileManager.default.createDirectory(
            at: filePathProvider.directoryURL(for: "UnsentDataHandlerTests")!, withIntermediateDirectories: true)

        context = CrashReporterContext(
            appId: TestConstants.appId,
            sdkVersion: TestConstants.sdkVersion,
            filePathProvider: filePathProvider,
            notificationCenter: NotificationCenter.default
        )

        let urlSessionconfig = URLSessionConfiguration.ephemeral
        urlSessionconfig.httpMaximumConnectionsPerHost = .max
        urlSessionconfig.protocolClasses = [EmbraceHTTPMock.self]

        uploadOptions = EmbraceUpload.Options(
            endpoints: testEndpointOptions(forTest: testName),
            cache: EmbraceUpload.CacheOptions(
                storageMechanism: .inMemory(name: testName), enableBackgroundTasks: false),
            metadata: UnsentDataHandlerTests.testMetadataOptions,
            redundancy: UnsentDataHandlerTests.testRedundancyOptions,
            urlSessionConfiguration: urlSessionconfig
        )

        self.queue = DispatchQueue(label: "com.test.embrace.queue")
    }

    override func tearDownWithError() throws {
        // delete tmpdir
        try? FileManager.default.removeItem(at: filePathProvider.tmpDirectory)

        EmbraceHTTPMock.clearRequests()
    }

    func test_withoutCrashReporter() async throws {
        try XCTSkipIf(XCTestCase.isWatchOS(), "Unavailable on WatchOS")
        // mock successful requests
        EmbraceHTTPMock.mock(url: testSpansUrl())

        // given a storage and upload modules
        let storage = try EmbraceStorage.createInMemoryDb()
        defer { storage.coreData.destroy() }

        let upload = try EmbraceUpload(
            options: uploadOptions, logger: logger, queue: queue)

        let otel = MockOTelSignalsHandler()

        // given a finished session in the storage
        await storage.addSession(
            id: TestConstants.sessionId,
            processId: ProcessIdentifier.current,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date(timeIntervalSinceNow: -60),
            endTime: Date()
        )

        // when sending unsent sessions
        await UnsentDataHandler.sendUnsentData(storage: storage, upload: upload, otel: otel, crashReporter: nil)
        wait(timeout: .longTimeout, interval: .shortInterval, until: { upload.cache.fetchAllUploadData().isEmpty })

        // then a session request was sent
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(testSpansUrl()).count, 1)

        // then the session is no longer on storage
        let session = storage.fetchSession(id: TestConstants.sessionId)
        XCTAssertNil(session)

        // then the session upload data is no longer cached
        let uploadData = upload.cache.fetchAllUploadData()
        XCTAssertEqual(uploadData.count, 0)

        // then no log was sent
        XCTAssertEqual(otel.logs.count, 0)
    }

    func test_withoutCrashReporter_error() async throws {
        try XCTSkipIf(XCTestCase.isWatchOS(), "Unavailable on WatchOS")
        // mock error requests
        EmbraceHTTPMock.mock(url: testSpansUrl(), errorCode: 500)

        // given a storage and upload modules (no retries so request count is deterministic)
        let storage = try EmbraceStorage.createInMemoryDb()
        defer { storage.coreData.destroy() }

        let noRetryOptions = uploadOptions(automaticRetryCount: 0)
        let upload = try EmbraceUpload(
            options: noRetryOptions, logger: logger, queue: queue)

        let otel = MockOTelSignalsHandler()

        // given a finished session in the storage
        await storage.addSession(
            id: TestConstants.sessionId,
            processId: ProcessIdentifier.current,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date(timeIntervalSinceNow: -60),
            endTime: Date()
        )

        // when failing to send unsent sessions
        await UnsentDataHandler.sendUnsentData(storage: storage, upload: upload, otel: otel, crashReporter: nil)
        wait(timeout: .longTimeout, interval: .shortInterval, until: { EmbraceHTTPMock.totalRequestCount() == 1 })

        // then a session request was attempted
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(testSpansUrl()).count, 1)

        // then the total amount of requests is correct
        XCTAssertEqual(EmbraceHTTPMock.totalRequestCount(), 1)

        // then the session is no longer on storage
        let session = storage.fetchSession(id: TestConstants.sessionId)
        XCTAssertNil(session)

        // then no log was sent
        XCTAssertEqual(otel.logs.count, 0)
    }

    func test_withCrashReporter() async throws {
        try XCTSkipIf(XCTestCase.isWatchOS(), "Unavailable on watchOS")
        // mock successful requests
        EmbraceHTTPMock.mock(url: testSpansUrl())
        EmbraceHTTPMock.mock(url: testLogsUrl())

        // given a storage and upload modules
        let storage = try EmbraceStorage.createInMemoryDb()
        defer { storage.coreData.destroy() }

        let upload = try EmbraceUpload(
            options: uploadOptions, logger: logger, queue: queue)

        let otel = MockOTelSignalsHandler()

        // given a crash reporter
        let crashReporter = CrashReporterMock(crashSessionId: TestConstants.sessionId.stringValue)
        let embraceReporter = EmbraceCrashReporter(reporter: crashReporter)
        let report = crashReporter.mockReports[0]

        // given a finished session in the storage
        await storage.addSession(
            id: TestConstants.sessionId,
            processId: ProcessIdentifier.current,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date(timeIntervalSinceNow: -60),
            endTime: Date()
        )

        // the crash report id is set on the session
        let listener = CoreDataListener()
        let expectation1 = XCTestExpectation()
        listener.onUpdatedObjects = { records in
            if let record = records.first as? SessionRecord,
                record.crashReportId != nil
            {
                expectation1.fulfill()
            }
        }

        // when sending unsent sessions
        await UnsentDataHandler.sendUnsentData(
            storage: storage, upload: upload, otel: otel, crashReporter: embraceReporter)
        wait(timeout: .longTimeout, interval: .shortInterval, until: { upload.cache.fetchAllUploadData().isEmpty })

        // then a crash report was sent
        // then a session request was sent
        XCTAssert(EmbraceHTTPMock.requestsForUrl(self.testLogsUrl()).count == 1)
        XCTAssert(EmbraceHTTPMock.requestsForUrl(self.testSpansUrl()).count == 1)

        // then the total amount of requests is correct
        XCTAssertEqual(EmbraceHTTPMock.totalRequestCount(), 2)

        // then the session is no longer on storage
        let session = storage.fetchSession(id: TestConstants.sessionId)
        XCTAssertNil(session)

        // then the session and crash report upload data is no longer cached
        let uploadData = upload.cache.fetchAllUploadData()
        XCTAssertEqual(uploadData.count, 0)

        // then the crash is not longer stored
        let reports = await crashReporter.fetchUnsentCrashReports()
        XCTAssertEqual(reports.count, 0)

        // then the raw crash log was sent
        XCTAssertEqual(otel.logs.count, 1)
        XCTAssertEqual(otel.logs[0].attributes["emb.type"] as! String, EmbraceType.crash.rawValue)
        XCTAssertEqual(otel.logs[0].timestamp, report.timestamp)
    }

    func test_withCrashReporter_error() async throws {
        try XCTSkipIf(XCTestCase.isWatchOS(), "Unavailable on WatchOS")
        EmbraceHTTPMock.mock(url: testSpansUrl(), errorCode: 500)
        EmbraceHTTPMock.mock(url: testLogsUrl(), errorCode: 500)

        // given a storage and upload modules (no retries so request count is deterministic)
        let storage = try EmbraceStorage.createInMemoryDb()
        defer { storage.coreData.destroy() }

        let noRetryOptions = uploadOptions(automaticRetryCount: 0)
        let upload = try EmbraceUpload(
            options: noRetryOptions, logger: logger, queue: queue)

        let otel = MockOTelSignalsHandler()

        // given a crash reporter
        let crashReporter = CrashReporterMock(crashSessionId: TestConstants.sessionId.stringValue)
        let embraceReporter = EmbraceCrashReporter(reporter: crashReporter)
        let report = crashReporter.mockReports[0]

        // then the crash report id is set on the session
        let listener = CoreDataListener()
        let didSendCrashesExpectation = XCTestExpectation()
        listener.onUpdatedObjects = { records in
            if let record = records.first as? SessionRecord,
                record.crashReportId != nil
            {
                didSendCrashesExpectation.fulfill()
            }
        }

        // given a finished session in the storage
        await storage.addSession(
            id: TestConstants.sessionId,
            processId: ProcessIdentifier.current,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date(timeIntervalSinceNow: -60),
            endTime: Date()
        )

        // when failing to send unsent sessions
        await UnsentDataHandler.sendUnsentData(
            storage: storage, upload: upload, otel: otel, crashReporter: embraceReporter)

        await fulfillment(of: [didSendCrashesExpectation], timeout: .defaultTimeout)
        wait(timeout: .longTimeout, interval: .shortInterval, until: { EmbraceHTTPMock.totalRequestCount() == 2 })

        // then a crash report request was attempted
        // then a session request was attempted
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(self.testLogsUrl()).count, 1)
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(self.testSpansUrl()).count, 1)

        // then the total amount of requests is correct
        XCTAssertEqual(EmbraceHTTPMock.totalRequestCount(), 2)

        // then the session is no longer on storage
        let session = storage.fetchSession(id: TestConstants.sessionId)
        XCTAssertNil(session)

        // then the crash is not longer stored
        let reports = await crashReporter.fetchUnsentCrashReports()
        XCTAssertEqual(reports.count, 0)

        // then the raw crash log was sent
        XCTAssertEqual(otel.logs.count, 1)
        XCTAssertEqual(otel.logs[0].attributes["emb.type"] as! String, EmbraceType.crash.rawValue)
        XCTAssertEqual(otel.logs[0].timestamp, report.timestamp)
    }

    func test_withCrashReporter_unfinishedSession() async throws {
        try XCTSkipIf(XCTestCase.isWatchOS(), "Unavailable on WatchOS")
        // mock successful requests
        EmbraceHTTPMock.mock(url: testSpansUrl())
        EmbraceHTTPMock.mock(url: testLogsUrl())

        // given a storage and upload modules
        let storage = try EmbraceStorage.createInMemoryDb()
        defer { storage.coreData.destroy() }

        let upload = try EmbraceUpload(
            options: uploadOptions, logger: logger, queue: queue)

        let otel = MockOTelSignalsHandler()

        // given a crash reporter
        let crashReporter = CrashReporterMock(crashSessionId: TestConstants.sessionId.stringValue)
        let embraceReporter = EmbraceCrashReporter(reporter: crashReporter)
        let report = crashReporter.mockReports[0]

        // given an unfinished session in the storage
        await storage.addSession(
            id: TestConstants.sessionId,
            processId: ProcessIdentifier.current,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date(timeIntervalSinceNow: -60)
        )

        // the crash report id and timestamp is set on the session
        let listener = CoreDataListener()
        let expectation1 = XCTestExpectation()
        listener.onUpdatedObjects = { records in
            if let record = records.first as? SessionRecord,
                record.crashReportId != nil,
                record.endTime != nil
            {
                expectation1.fulfill()
            }
        }

        // when sending unsent sessions
        await UnsentDataHandler.sendUnsentData(
            storage: storage, upload: upload, otel: otel, crashReporter: embraceReporter)
        wait(timeout: .longTimeout, interval: .shortInterval, until: { upload.cache.fetchAllUploadData().isEmpty })

        // then a crash report was sent
        // then a session request was sent
        XCTAssert(EmbraceHTTPMock.requestsForUrl(self.testLogsUrl()).count == 1)
        XCTAssert(EmbraceHTTPMock.requestsForUrl(self.testSpansUrl()).count == 1)

        // then the total amount of requests is correct
        XCTAssertEqual(EmbraceHTTPMock.totalRequestCount(), 2)

        // then the session is no longer on storage
        let session = storage.fetchSession(id: TestConstants.sessionId)
        XCTAssertNil(session)

        // then the session and crash report upload data is no longer cached
        XCTAssert(upload.cache.fetchAllUploadData().count == 0)

        let reports = await crashReporter.fetchUnsentCrashReports()
        XCTAssertEqual(reports.count, 0)

        // then the raw crash log was sent
        XCTAssertEqual(otel.logs.count, 1)
        XCTAssertEqual(otel.logs[0].attributes["emb.type"] as! String, EmbraceType.crash.rawValue)
        XCTAssertEqual(otel.logs[0].timestamp, report.timestamp)
    }

    func test_sendCrashLog() async throws {
        try XCTSkipIf(XCTestCase.isWatchOS(), "Unavailable on WatchOS")
        // mock successful requests
        EmbraceHTTPMock.mock(url: testLogsUrl())

        // given a storage and upload modules
        let storage = try EmbraceStorage.createInMemoryDb()
        defer { storage.coreData.destroy() }

        let upload = try EmbraceUpload(
            options: uploadOptions, logger: logger, queue: queue)
        let otel = MockOTelSignalsHandler()

        // given a crash reporter
        let crashReporter = CrashReporterMock(crashSessionId: TestConstants.sessionId.stringValue)
        let embraceReporter = EmbraceCrashReporter(reporter: crashReporter)
        let report = crashReporter.mockReports[0]

        // given a finished session in the storage
        let session = await storage.addSession(
            id: TestConstants.sessionId,
            processId: ProcessIdentifier.current,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date(timeIntervalSinceNow: -60),
            endTime: Date()
        )

        // when sending a crash log
        await UnsentDataHandler.sendCrashLog(
            report: report,
            reporter: embraceReporter,
            session: session,
            storage: storage,
            upload: upload,
            otel: otel
        )
        wait(timeout: .longTimeout, interval: .shortInterval, until: { upload.cache.fetchAllUploadData().isEmpty })

        // then a crash log was sent
        XCTAssert(EmbraceHTTPMock.requestsForUrl(self.testLogsUrl()).count > 0)

        // then the total amount of requests is correct
        XCTAssertEqual(EmbraceHTTPMock.totalRequestCount(), 1)

        // then the crash log upload data is no longer cached
        let uploadData = upload.cache.fetchAllUploadData()
        XCTAssertEqual(uploadData.count, 0)

        // then the raw crash log was constructed correctly
        XCTAssertEqual(otel.logs.count, 1)
        XCTAssertEqual(otel.logs[0].type, .crash)
        XCTAssertEqual(otel.logs[0].timestamp, report.timestamp)
        XCTAssertEqual(otel.logs[0].body, "")
        XCTAssertEqual(otel.logs[0].severity, .fatal)
        XCTAssertEqual(
            otel.logs[0].attributes["emb.session_part_id"] as! String,
            TestConstants.sessionId.stringValue
        )
        XCTAssertEqual(otel.logs[0].attributes["emb.state"] as! String, SessionState.foreground.rawValue)
        XCTAssertEqual(otel.logs[0].attributes["log.record.uid"] as! String, report.id.withoutHyphen)
        XCTAssertEqual(otel.logs[0].attributes["emb.provider"] as! String, report.provider)
        XCTAssertEqual(otel.logs[0].attributes["emb.payload"] as! String, report.payload)
    }

    func test_sendCrashReports_stampsCrashTerminationReasonOnLinkedSession() async throws {
        try XCTSkipIf(XCTestCase.isWatchOS(), "Unavailable on watchOS")

        let storage = try EmbraceStorage.createInMemoryDb()
        defer { storage.coreData.destroy() }

        let otel = MockOTelSignalsHandler()
        let crashReporter = CrashReporterMock(crashSessionId: TestConstants.sessionId.stringValue)
        let embraceReporter = EmbraceCrashReporter(reporter: crashReporter)

        // and a finished session in storage that the crash report will link to
        await storage.addSession(
            id: TestConstants.sessionId,
            processId: ProcessIdentifier.current,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date(timeIntervalSinceNow: -60),
            endTime: Date()
        )

        // The session is deleted by `sendUnsentData`'s session-uploader path at the end of
        // the flow, so observe the in-flight update via a Core Data listener — it captures
        // the moment `updateSession` writes the new fields.
        let listener = CoreDataListener()
        let didStamp = XCTestExpectation()
        listener.onUpdatedObjects = { records in
            for record in records {
                if let session = record as? SessionRecord,
                    session.crashReportId != nil,
                    session.userSessionTerminationReason == TerminationReason.crash.rawValue
                {
                    didStamp.fulfill()
                    return
                }
            }
        }

        await UnsentDataHandler.sendUnsentData(
            storage: storage, upload: nil, otel: otel, crashReporter: embraceReporter
        )

        await fulfillment(of: [didStamp], timeout: .defaultTimeout)
        _ = listener  // keep alive for the duration of the test
    }

    func test_sendCrashReports_unlinkedReport_doesNotCrash() async throws {
        try XCTSkipIf(XCTestCase.isWatchOS(), "Unavailable on watchOS")

        let storage = try EmbraceStorage.createInMemoryDb()
        defer { storage.coreData.destroy() }

        let otel = MockOTelSignalsHandler()
        // Crash report points at a session id that doesn't exist in storage.
        let crashReporter = CrashReporterMock(crashSessionId: EmbraceIdentifier.random.stringValue)
        let embraceReporter = EmbraceCrashReporter(reporter: crashReporter)

        // no exception expected; storage stays empty
        await UnsentDataHandler.sendUnsentData(
            storage: storage, upload: nil, otel: otel, crashReporter: embraceReporter
        )
        wait(delay: .shortTimeout)

        XCTAssertEqual((storage.fetchAll() as [SessionRecord]).count, 0)
    }

    func test_sendCrashReports_sessionFromPreviousProcess() async throws {
        try XCTSkipIf(XCTestCase.isWatchOS(), "Unavailable on WatchOS")
        // mock successful requests
        EmbraceHTTPMock.mock(url: testSpansUrl())
        EmbraceHTTPMock.mock(url: testLogsUrl())

        // given a storage and upload modules
        let storage = try EmbraceStorage.createInMemoryDb()
        defer { storage.coreData.destroy() }

        let upload = try EmbraceUpload(
            options: uploadOptions, logger: logger, queue: queue)

        let otel = MockOTelSignalsHandler()

        // given a crash reporter with a report tied to a session
        let crashReporter = CrashReporterMock(crashSessionId: TestConstants.sessionId.stringValue)
        let embraceReporter = EmbraceCrashReporter(reporter: crashReporter)

        // given that session in the storage, belonging to a previous process
        let previousProcessId = EmbraceIdentifier.random
        await storage.addSession(
            id: TestConstants.sessionId,
            processId: previousProcessId,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date(timeIntervalSinceNow: -60),
            endTime: Date()
        )

        // given experiments in storage for that process and for the current one
        storage.addMetadata(
            key: LogSemantics.keyExperiments,
            value: "previous_experiments",
            type: .requiredResource,
            lifespan: .process,
            lifespanId: previousProcessId.stringValue
        )
        storage.addMetadata(
            key: LogSemantics.keyExperiments,
            value: "current_experiments",
            type: .requiredResource,
            lifespan: .process,
            lifespanId: ProcessIdentifier.current.stringValue
        )

        // when sending unsent data
        await UnsentDataHandler.sendUnsentData(
            storage: storage, upload: upload, otel: otel, crashReporter: embraceReporter)
        wait(
            timeout: .longTimeout, interval: .shortInterval,
            until: { EmbraceHTTPMock.requestBodiesForUrl(self.testLogsUrl()).count == 1 })

        // then the crash log carries the experiments of the session's process, as a log attribute
        let attributes = try crashLogAttributes()
        XCTAssertEqual(attributes[LogSemantics.keyExperiments], "previous_experiments")

        // and never as a resource
        let resource = try crashLogResource()
        XCTAssertNil(resource[LogSemantics.keyExperiments])
    }

    func test_sendCrashReports_noSessionWithProcessId() async throws {
        try XCTSkipIf(XCTestCase.isWatchOS(), "Unavailable on WatchOS")
        // mock successful requests
        EmbraceHTTPMock.mock(url: testSpansUrl())
        EmbraceHTTPMock.mock(url: testLogsUrl())

        // given a storage and upload modules
        let storage = try EmbraceStorage.createInMemoryDb()
        defer { storage.coreData.destroy() }

        let upload = try EmbraceUpload(
            options: uploadOptions, logger: logger, queue: queue)

        let otel = MockOTelSignalsHandler()

        // given a crash reporter with a report that has no session but knows its process
        let previousProcessId = EmbraceIdentifier.random
        let crashReporter = CrashReporterMock(
            mockReports: [
                EmbraceCrashReport(
                    payload: "test",
                    provider: "mock",
                    internalId: 123,
                    sessionId: nil,
                    processId: previousProcessId.stringValue,
                    timestamp: Date()
                )
            ]
        )
        let embraceReporter = EmbraceCrashReporter(reporter: crashReporter)

        // given experiments in storage for that process and for the current one
        storage.addMetadata(
            key: LogSemantics.keyExperiments,
            value: "previous_experiments",
            type: .requiredResource,
            lifespan: .process,
            lifespanId: previousProcessId.stringValue
        )
        storage.addMetadata(
            key: LogSemantics.keyExperiments,
            value: "current_experiments",
            type: .requiredResource,
            lifespan: .process,
            lifespanId: ProcessIdentifier.current.stringValue
        )

        // when sending unsent data
        await UnsentDataHandler.sendUnsentData(
            storage: storage, upload: upload, otel: otel, crashReporter: embraceReporter)
        wait(
            timeout: .longTimeout, interval: .shortInterval,
            until: { EmbraceHTTPMock.requestBodiesForUrl(self.testLogsUrl()).count == 1 })

        // then the crash log carries the experiments of the process in the report
        let attributes = try crashLogAttributes()
        XCTAssertEqual(attributes[LogSemantics.keyExperiments], "previous_experiments")
    }

    func test_sendCrashReports_noSessionNoProcessId() async throws {
        try XCTSkipIf(XCTestCase.isWatchOS(), "Unavailable on WatchOS")
        // mock successful requests
        EmbraceHTTPMock.mock(url: testSpansUrl())
        EmbraceHTTPMock.mock(url: testLogsUrl())

        // given a storage and upload modules
        let storage = try EmbraceStorage.createInMemoryDb()
        defer { storage.coreData.destroy() }

        let upload = try EmbraceUpload(
            options: uploadOptions, logger: logger, queue: queue)

        let otel = MockOTelSignalsHandler()

        // given a crash reporter with a report that has no session nor process
        let crashReporter = CrashReporterMock(
            mockReports: [
                EmbraceCrashReport(
                    payload: "test",
                    provider: "mock",
                    internalId: 123,
                    sessionId: nil,
                    processId: nil,
                    timestamp: Date()
                )
            ]
        )
        let embraceReporter = EmbraceCrashReporter(reporter: crashReporter)

        // given metadata in storage for the current process
        storage.addMetadata(
            key: LogSemantics.keyExperiments,
            value: "current_experiments",
            type: .requiredResource,
            lifespan: .process,
            lifespanId: ProcessIdentifier.current.stringValue
        )
        storage.addMetadata(
            key: AppResourceKey.appVersion.rawValue,
            value: "1.0.0",
            type: .requiredResource,
            lifespan: .process,
            lifespanId: ProcessIdentifier.current.stringValue
        )

        // when sending unsent data
        await UnsentDataHandler.sendUnsentData(
            storage: storage, upload: upload, otel: otel, crashReporter: embraceReporter)
        wait(
            timeout: .longTimeout, interval: .shortInterval,
            until: { EmbraceHTTPMock.requestBodiesForUrl(self.testLogsUrl()).count == 1 })

        // then the crash log doesn't carry the experiments of the process sending it
        let attributes = try crashLogAttributes()
        XCTAssertNil(attributes[LogSemantics.keyExperiments])

        // nor any other resource of that process: the crash belongs to a process we can't identify,
        // and this one describes the launch that found the crash, not the one that crashed
        let resource = try crashLogResource()
        XCTAssertNil(resource["app_version"] as? String)
    }

    func test_sendCrashReports_exportedLog_describesTheCrashedSession() async throws {
        try XCTSkipIf(XCTestCase.isWatchOS(), "Unavailable on WatchOS")
        // mock successful requests
        EmbraceHTTPMock.mock(url: testSpansUrl())
        EmbraceHTTPMock.mock(url: testLogsUrl())

        // given a storage and upload modules
        let storage = try EmbraceStorage.createInMemoryDb()
        defer { storage.coreData.destroy() }

        let upload = try EmbraceUpload(
            options: uploadOptions, logger: logger, queue: queue)

        let otel = MockOTelSignalsHandler()

        // given a crash reporter with a report tied to a session
        let crashReporter = CrashReporterMock(crashSessionId: TestConstants.sessionId.stringValue)
        let embraceReporter = EmbraceCrashReporter(reporter: crashReporter)
        let report = crashReporter.mockReports[0]

        // given that session in the storage, backgrounded and belonging to a previous process
        let previousProcessId = EmbraceIdentifier.random
        let previousUserSessionId = EmbraceIdentifier.random
        await storage.addSession(
            id: TestConstants.sessionId,
            processId: previousProcessId,
            state: .background,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date(timeIntervalSinceNow: -60),
            endTime: Date(),
            userSessionId: previousUserSessionId
        )

        // given experiments in storage for that process and for the current one
        storage.addMetadata(
            key: LogSemantics.keyExperiments,
            value: "previous_experiments",
            type: .requiredResource,
            lifespan: .process,
            lifespanId: previousProcessId.stringValue
        )
        storage.addMetadata(
            key: LogSemantics.keyExperiments,
            value: "current_experiments",
            type: .requiredResource,
            lifespan: .process,
            lifespanId: ProcessIdentifier.current.stringValue
        )

        // when sending unsent data
        await UnsentDataHandler.sendUnsentData(
            storage: storage, upload: upload, otel: otel, crashReporter: embraceReporter)
        wait(
            timeout: .longTimeout, interval: .shortInterval,
            until: { EmbraceHTTPMock.requestBodiesForUrl(self.testLogsUrl()).count == 1 })
        wait(timeout: .defaultTimeout, until: { otel.logs.count == 1 })

        // then the log pushed through the OTel pipeline describes the session and the process
        // that crashed, not the ones sending it
        let exported = try XCTUnwrap(otel.logs.first)
        XCTAssertEqual(exported.type, .crash)
        XCTAssertEqual(exported.severity, .fatal)
        XCTAssertEqual(exported.timestamp, report.timestamp)
        XCTAssertEqual(exported.sessionId, TestConstants.sessionId)
        XCTAssertEqual(exported.processId, previousProcessId)

        XCTAssertEqual(exported.attributes[LogSemantics.keyPartId] as? String, TestConstants.sessionId.stringValue)
        XCTAssertEqual(exported.attributes[LogSemantics.keySessionId] as? String, previousUserSessionId.stringValue)
        XCTAssertEqual(
            exported.attributes[LogSemantics.keyUserSessionId] as? String,
            previousUserSessionId.stringValue
        )
        XCTAssertEqual(exported.attributes[LogSemantics.keyState] as? String, SessionState.background.rawValue)
        XCTAssertEqual(exported.attributes[LogSemantics.keyExperiments] as? String, "previous_experiments")

        // then the log is identified by the crash report it carries
        XCTAssertEqual(exported.id, report.id.withoutHyphen)
        XCTAssertEqual(exported.attributes[LogSemantics.Crash.keyId] as? String, report.id.withoutHyphen)
    }

    func test_sendCrashReports_exportedLog_noSessionNoProcessId_hasNoExperiments() async throws {
        try XCTSkipIf(XCTestCase.isWatchOS(), "Unavailable on WatchOS")
        // mock successful requests
        EmbraceHTTPMock.mock(url: testSpansUrl())
        EmbraceHTTPMock.mock(url: testLogsUrl())

        // given a storage and upload modules
        let storage = try EmbraceStorage.createInMemoryDb()
        defer { storage.coreData.destroy() }

        let upload = try EmbraceUpload(
            options: uploadOptions, logger: logger, queue: queue)

        let otel = MockOTelSignalsHandler()

        // given a crash reporter with a report that has no session nor process
        let crashReporter = CrashReporterMock(
            mockReports: [
                EmbraceCrashReport(
                    payload: "test",
                    provider: "mock",
                    internalId: 123,
                    sessionId: nil,
                    processId: nil,
                    timestamp: Date()
                )
            ]
        )
        let embraceReporter = EmbraceCrashReporter(reporter: crashReporter)

        // given experiments in storage for the current process
        storage.addMetadata(
            key: LogSemantics.keyExperiments,
            value: "current_experiments",
            type: .requiredResource,
            lifespan: .process,
            lifespanId: ProcessIdentifier.current.stringValue
        )

        // when sending unsent data
        await UnsentDataHandler.sendUnsentData(
            storage: storage, upload: upload, otel: otel, crashReporter: embraceReporter)
        wait(
            timeout: .longTimeout, interval: .shortInterval,
            until: { EmbraceHTTPMock.requestBodiesForUrl(self.testLogsUrl()).count == 1 })
        wait(timeout: .defaultTimeout, until: { otel.logs.count == 1 })

        // then the log pushed through the OTel pipeline carries no experiments: the crash belongs
        // to a process that can't be identified, so the ones of this process would be a wrong guess
        let exported = try XCTUnwrap(otel.logs.first)
        XCTAssertNil(exported.attributes[LogSemantics.keyExperiments])
    }

    func test_spanCleanUp_sendUnsentData() async throws {
        // mock successful requests
        EmbraceHTTPMock.mock(url: testSpansUrl())
        EmbraceHTTPMock.mock(url: testLogsUrl())

        // given a storage and upload modules
        let storage = try EmbraceStorage.createInMemoryDb()
        defer { storage.coreData.destroy() }

        let upload = try EmbraceUpload(
            options: uploadOptions, logger: logger, queue: queue)

        let otel = MockOTelSignalsHandler()

        // given an unfinished session in the storage
        await storage.addSession(
            id: TestConstants.sessionId,
            processId: ProcessIdentifier.current,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date(timeIntervalSinceNow: -60)
        )

        // given old closed span in storage
        storage.upsertSpan(
            MockSpan(
                id: "oldSpan",
                traceId: "traceId",
                name: "test",
                type: .performance,
                startTime: Date(timeIntervalSinceNow: -100),
                endTime: Date(timeIntervalSinceNow: -80)
            ))

        // given open span in storage
        storage.upsertSpan(
            MockSpan(
                id: TestConstants.spanId,
                traceId: TestConstants.traceId,
                name: "test",
                type: .performance,
                startTime: Date(timeIntervalSinceNow: -50),
                processId: TestConstants.processId
            ))

        // when sending unsent sessions
        await UnsentDataHandler.sendUnsentData(storage: storage, upload: upload, otel: otel)
        wait(
            timeout: .longTimeout, interval: .shortInterval,
            until: {
                let spans: [SpanRecord] = storage.fetchAll()
                return spans.count == 1 && spans[0].endTime != nil
            })

        // then the old closed span was removed
        // and the open span was closed
        var spans: [SpanRecord] = storage.fetchAll()
        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(spans[0].id, TestConstants.spanId)
        XCTAssertEqual(spans[0].traceId, TestConstants.traceId)
        XCTAssertNotNil(spans[0].endTime)

        // when sending unsent sessions again
        await UnsentDataHandler.sendUnsentData(storage: storage, upload: upload, otel: otel)

        // then the span that was closed for the last session
        // is not valid anymore, and therefore removed
        spans = storage.fetchAll()
        XCTAssertEqual(spans.count, 0)
    }

    func test_metadataCleanUp_sendUnsendData() async throws {
        // mock successful requests
        EmbraceHTTPMock.mock(url: testSpansUrl())
        EmbraceHTTPMock.mock(url: testLogsUrl())

        // given a storage and upload modules
        let storage = try EmbraceStorage.createInMemoryDb()
        defer { storage.coreData.destroy() }

        let upload = try EmbraceUpload(
            options: uploadOptions, logger: logger, queue: queue)

        let otel = MockOTelSignalsHandler()

        // given an unfinished session part in the storage
        await storage.addSession(
            id: TestConstants.sessionId,
            processId: ProcessIdentifier.current,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date(timeIntervalSinceNow: -60),
            userSessionId: TestConstants.userSessionId
        )

        // given metadata in storage
        storage.addMetadata(
            key: "permanent",
            value: "test",
            type: .requiredResource,
            lifespan: .permanent
        )
        storage.addMetadata(
            key: "sameUserSessionId",
            value: "test",
            type: .requiredResource,
            lifespan: .userSession,
            lifespanId: TestConstants.userSessionId.stringValue
        )
        storage.addMetadata(
            key: "sameProcessId",
            value: "test",
            type: .requiredResource,
            lifespan: .process,
            lifespanId: ProcessIdentifier.current.stringValue
        )
        storage.addMetadata(
            key: "differentUserSessionId",
            value: "test",
            type: .requiredResource,
            lifespan: .userSession,
            lifespanId: "test"
        )
        storage.addMetadata(
            key: "differentProcessId",
            value: "test",
            type: .requiredResource,
            lifespan: .process,
            lifespanId: "test"
        )

        // when sending unsent sessions
        await UnsentDataHandler.sendUnsentData(
            storage: storage,
            upload: upload,
            otel: otel,
            currentSessionId: TestConstants.sessionId,
            currentUserSessionId: TestConstants.userSessionId
        )
        wait(
            timeout: .longTimeout, interval: .shortInterval,
            until: {
                let records: [MetadataRecord] = storage.fetchAll()
                return !records.contains(where: { $0.key == "differentUserSessionId" })
                    && !records.contains(where: { $0.key == "differentProcessId" })
            })

        // then all metadata is cleaned up
        let records: [MetadataRecord] = storage.fetchAll()
        XCTAssertNotNil(records.first(where: { $0.key == "permanent" }))
        XCTAssertNotNil(records.first(where: { $0.key == "sameUserSessionId" }))
        XCTAssertNotNil(records.first(where: { $0.key == "sameProcessId" }))
        XCTAssertNil(records.first(where: { $0.key == "differentUserSessionId" }))
        XCTAssertNil(records.first(where: { $0.key == "differentProcessId" }))
    }

    func test_spanCleanUp_uploadSession() async throws {
        // mock successful requests
        EmbraceHTTPMock.mock(url: testSpansUrl())
        EmbraceHTTPMock.mock(url: testLogsUrl())

        // given a storage and upload modules
        let storage = try EmbraceStorage.createInMemoryDb()
        defer { storage.coreData.destroy() }

        let upload = try EmbraceUpload(
            options: uploadOptions, logger: logger, queue: queue)

        // given an unfinished session in the storage
        let session = await storage.addSession(
            id: TestConstants.sessionId,
            processId: ProcessIdentifier.current,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date(timeIntervalSinceNow: -60)
        )!

        // given old closed span in storage
        storage.upsertSpan(
            MockSpan(
                id: "oldSpan",
                traceId: "traceId",
                name: "test",
                type: .performance,
                startTime: Date(timeIntervalSinceNow: -100),
                endTime: Date(timeIntervalSinceNow: -80)
            ))

        // when uploading the session
        await UnsentDataHandler.sendSession(session, storage: storage, upload: upload)
        wait(
            timeout: .longTimeout, interval: .shortInterval,
            until: {
                let spans: [SpanRecord] = storage.fetchAll()
                let sessions: [SessionRecord] = storage.fetchAll()
                return spans.isEmpty && sessions.isEmpty
            })

        // then the old closed span was removed
        // and the session was removed
        let spans: [SpanRecord] = storage.fetchAll()
        let sessions: [SessionRecord] = storage.fetchAll()
        XCTAssertEqual(spans.count, 0)
        XCTAssertEqual(sessions.count, 0)
    }

    func test_metadataCleanUp_uploadSession() async throws {
        // mock successful requests
        EmbraceHTTPMock.mock(url: testSpansUrl())
        EmbraceHTTPMock.mock(url: testLogsUrl())

        // given a storage and upload modules
        let storage = try EmbraceStorage.createInMemoryDb()
        defer { storage.coreData.destroy() }

        let upload = try EmbraceUpload(
            options: uploadOptions, logger: logger, queue: queue)

        // given an unfinished session in the storage
        let session = await storage.addSession(
            id: TestConstants.sessionId,
            processId: ProcessIdentifier.current,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date(timeIntervalSinceNow: -60)
        )!

        // given metadata in storage
        storage.addMetadata(
            key: "permanent",
            value: "test",
            type: .requiredResource,
            lifespan: .permanent
        )
        storage.addMetadata(
            key: "sameProcessId",
            value: "test",
            type: .requiredResource,
            lifespan: .process,
            lifespanId: ProcessIdentifier.current.stringValue
        )
        storage.addMetadata(
            key: "differentProcessId",
            value: "test",
            type: .requiredResource,
            lifespan: .process,
            lifespanId: "test"
        )

        // when uploading the session
        await UnsentDataHandler.sendSession(session, storage: storage, upload: upload)
        wait(
            timeout: .longTimeout, interval: .shortInterval,
            until: {
                let records: [MetadataRecord] = storage.fetchAll()
                return !records.contains(where: { $0.key == "differentProcessId" })
            })

        // then metadata is correctly cleaned up
        let records: [MetadataRecord] = storage.fetchAll()
        XCTAssertNotNil(records.first(where: { $0.key == "permanent" }))
        XCTAssertNotNil(records.first(where: { $0.key == "sameProcessId" }))
        XCTAssertNil(records.first(where: { $0.key == "differentProcessId" }))
    }

    func test_logsUpload() async throws {
        try XCTSkipIf(XCTestCase.isWatchOS(), "Unavailable on WatchOS")
        // mock successful requests
        EmbraceHTTPMock.mock(url: testSpansUrl())
        EmbraceHTTPMock.mock(url: testLogsUrl())

        // given a storage and upload modules
        let storage = try EmbraceStorage.createInMemoryDb()
        defer { storage.coreData.destroy() }

        let upload = try EmbraceUpload(
            options: uploadOptions, logger: logger, queue: queue)
        let logController = LogController(
            storage: storage,
            upload: upload,
            sessionController: MockSessionController(),
            queue: DispatchQueue.main
        )
        logController.sdkStateProvider = sdkStateProvider
        logController.maxLogsPerBatchProvider = { LogController.maxLogsPerBatch }
        let otel = MockOTelSignalsHandler()

        // given the resources required for the payload to be valid
        storage.addMetadata(
            key: AppResourceKey.appVersion.rawValue,
            value: "1.2.3",
            type: .requiredResource,
            lifespan: .process,
            lifespanId: TestConstants.processId.stringValue
        )

        // given logs in storage
        for _ in 0...5 {
            storage.saveLog(
                MockLog(
                    id: EmbraceIdentifier.random.stringValue,
                    severity: .debug,
                    body: "test",
                    attributes: [:],
                    sessionId: nil,
                    processId: TestConstants.processId
                ))
        }

        // when sending unsent data
        await UnsentDataHandler.sendUnsentData(
            storage: storage, upload: upload, otel: otel, logController: logController)
        wait(timeout: .longTimeout, interval: .shortInterval, until: { EmbraceHTTPMock.requestsForUrl(self.testLogsUrl()).count == 1 })

        // then no sessions were sent
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(testSpansUrl()).count, 0)

        // then a log batch was sent
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(testLogsUrl()).count, 1)
    }

    func test_criticalLogs() async throws {
        try XCTSkipIf(XCTestCase.isWatchOS(), "Unavailable on WatchOS")
        // mock successful requests
        EmbraceHTTPMock.mock(url: testLogsUrl())

        // given upload module
        let upload = try EmbraceUpload(
            options: uploadOptions, logger: logger, queue: queue)

        // given critical logs file present
        try "TEST".write(to: criticalLogsFilePath, atomically: true, encoding: .utf8)

        // when sending critical logs
        await UnsentDataHandler.sendCriticalLogs(fileUrl: criticalLogsFilePath, upload: upload)
        wait(timeout: .longTimeout, interval: .shortInterval, until: { EmbraceHTTPMock.requestsForUrl(self.testLogsUrl()).count == 1 })

        // then a log is sent
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(testLogsUrl()).count, 1)
    }

    func test_criticalLogs_noFile() async throws {
        // mock successful requests
        EmbraceHTTPMock.mock(url: testLogsUrl())

        // given upload module
        let upload = try EmbraceUpload(
            options: uploadOptions, logger: logger, queue: queue)

        // when sending critical logs without a file present
        // sendCriticalLogs is synchronous when fileUrl has no contents — no upload is
        // ever enqueued, the closure-completion fires inline, and the continuation
        // resumes. No async work to wait for after the await returns.
        await UnsentDataHandler.sendCriticalLogs(fileUrl: criticalLogsFilePath, upload: upload)

        // then no log is sent
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(testLogsUrl()).count, 0)
    }

    func test_criticalLogs_orphanPendingFile_isDeleted() async throws {
        // mock successful requests
        EmbraceHTTPMock.mock(url: testLogsUrl())

        // given upload module
        let upload = try EmbraceUpload(
            options: uploadOptions, logger: logger, queue: queue)

        // given a stranded pending-logs file from a prior run that didn't fire .critical
        let pendingLogsFilePath = filePathProvider.fileURL(for: "UnsentDataHandlerTests", name: "pending-file")!
        try "STARTUP-TRAIL".write(to: pendingLogsFilePath, atomically: true, encoding: .utf8)
        XCTAssertTrue(FileManager.default.fileExists(atPath: pendingLogsFilePath.path))

        // when sending critical logs (no critical-logs file exists)
        await UnsentDataHandler.sendCriticalLogs(
            fileUrl: criticalLogsFilePath,
            pendingFileUrl: pendingLogsFilePath,
            upload: upload
        )
        wait(
            timeout: .longTimeout, interval: .shortInterval,
            until: {
                !FileManager.default.fileExists(atPath: pendingLogsFilePath.path)
            })

        // then nothing is uploaded and the orphan is gone
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(testLogsUrl()).count, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: pendingLogsFilePath.path))
    }
}

extension UnsentDataHandlerTests {
    fileprivate func testEndpointOptions(forTest testName: String) -> EmbraceUpload.EndpointOptions {
        .init(
            spansURL: testSpansUrl(forTest: testName),
            logsURL: testLogsUrl(forTest: testName),
            attachmentsURL: testAttachmentsUrl(forTest: testName)
        )
    }

    fileprivate func uploadOptions(automaticRetryCount: Int) -> EmbraceUpload.Options {
        let urlSessionConfig = URLSessionConfiguration.ephemeral
        urlSessionConfig.httpMaximumConnectionsPerHost = .max
        urlSessionConfig.protocolClasses = [EmbraceHTTPMock.self]

        return EmbraceUpload.Options(
            endpoints: testEndpointOptions(forTest: testName),
            cache: EmbraceUpload.CacheOptions(
                storageMechanism: .inMemory(name: testName), enableBackgroundTasks: false),
            metadata: UnsentDataHandlerTests.testMetadataOptions,
            redundancy: EmbraceUpload.RedundancyOptions(automaticRetryCount: automaticRetryCount),
            urlSessionConfiguration: urlSessionConfig
        )
    }

    /// Returns the attributes of the crash log that was uploaded, decompressing the request body.
    fileprivate func crashLogAttributes(forTest testName: String = #function) throws -> [String: String] {
        let bodies = EmbraceHTTPMock.requestBodiesForUrl(testLogsUrl(forTest: testName))
        let body = try XCTUnwrap(bodies.first)
        let payloadData = try body.gunzipped()
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: payloadData, options: []) as? [String: Any])
        let data = try XCTUnwrap(json["data"] as? [String: Any])
        let logs = try XCTUnwrap(data["logs"] as? [[String: Any]])
        let log = try XCTUnwrap(logs.first)
        let attributes = try XCTUnwrap(log["attributes"] as? [[String: Any]])

        return attributes.reduce(into: [:]) { result, attribute in
            if let key = attribute["key"] as? String, let value = attribute["value"] as? String {
                result[key] = value
            }
        }
    }

    /// Returns the `resource` block of the crash log payload that was uploaded, decompressing the request body.
    fileprivate func crashLogResource(forTest testName: String = #function) throws -> [String: Any] {
        let bodies = EmbraceHTTPMock.requestBodiesForUrl(testLogsUrl(forTest: testName))
        let body = try XCTUnwrap(bodies.first)
        let payloadData = try body.gunzipped()
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: payloadData, options: []) as? [String: Any])
        return try XCTUnwrap(json["resource"] as? [String: Any])
    }

    fileprivate func testSpansUrl(forTest testName: String = #function) -> URL {
        var url = URL(string: "https://embrace.test.com/sessions")!
        url.testName = testName
        return url
    }

    fileprivate func testLogsUrl(forTest testName: String = #function) -> URL {
        var url = URL(string: "https://embrace.test.com/logs")!
        url.testName = testName
        return url
    }

    fileprivate func testAttachmentsUrl(forTest testName: String = #function) -> URL {
        var url = URL(string: "https://embrace.test.com/attachments")!
        url.testName = testName
        return url
    }
}

extension EmbraceStorage {

    @discardableResult
    func addSession(
        id: EmbraceIdentifier,
        processId: EmbraceIdentifier,
        state: SessionState,
        traceId: String,
        spanId: String,
        startTime: Date,
        endTime: Date? = nil,
        lastHeartbeatTime: Date? = nil,
        crashReportId: String? = nil,
        coldStart: Bool = false,
        cleanExit: Bool = false,
        appTerminated: Bool = false
    ) async -> EmbraceSession? {
        await withCheckedContinuation { continuation in
            var session: EmbraceSession? = nil
            session = addSession(
                id: id, processId: processId, state: state, traceId: traceId, spanId: spanId, startTime: startTime
            ) {
                continuation.resume(returning: session)
            }
        }
    }

}
