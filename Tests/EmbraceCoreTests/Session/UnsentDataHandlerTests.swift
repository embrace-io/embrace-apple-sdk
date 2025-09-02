//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
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

    static let testRedundancyOptions = EmbraceUpload.RedundancyOptions(automaticRetryCount: 0)
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

        self.queue = DispatchQueue(label: "com.test.embrace.queue", attributes: .concurrent)
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
            options: uploadOptions, logger: logger, queue: queue, semaphore: .init(value: .max))

        let otel = MockEmbraceOpenTelemetry()

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

        // given a storage and upload modules
        let storage = try EmbraceStorage.createInMemoryDb()
        defer { storage.coreData.destroy() }

        let upload = try EmbraceUpload(
            options: uploadOptions, logger: logger, queue: queue, semaphore: .init(value: .max))

        let otel = MockEmbraceOpenTelemetry()

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

        // then a session request was attempted
        XCTAssertGreaterThan(EmbraceHTTPMock.requestsForUrl(testSpansUrl()).count, 0)

        // then the total amount of requests is correct
        XCTAssertEqual(EmbraceHTTPMock.totalRequestCount(), 1)

        // then the session is no longer on storage
        let session = storage.fetchSession(id: TestConstants.sessionId)
        XCTAssertNil(session)

        // then the session upload data cached
        let uploadData = upload.cache.fetchAllUploadData()
        XCTAssertEqual(uploadData.count, 1)

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
            options: uploadOptions, logger: logger, queue: queue, semaphore: .init(value: .max))

        let otel = MockEmbraceOpenTelemetry()

        // given a crash reporter
        let crashReporter = CrashReporterMock(crashSessionId: TestConstants.sessionId.toString)
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
        XCTAssertEqual(otel.logs[0].attributes["emb.type"], .string(LogType.crash.rawValue))
        XCTAssertEqual(otel.logs[0].timestamp, report.timestamp)
    }

    func test_withCrashReporter_error() async throws {
        try XCTSkipIf(XCTestCase.isWatchOS(), "Unavailable on WatchOS")
        EmbraceHTTPMock.mock(url: testSpansUrl(), errorCode: 500)
        EmbraceHTTPMock.mock(url: testLogsUrl(), errorCode: 500)

        // given a storage and upload modules
        let storage = try EmbraceStorage.createInMemoryDb()
        defer { storage.coreData.destroy() }

        let upload = try EmbraceUpload(
            options: uploadOptions, logger: logger, queue: queue, semaphore: .init(value: .max))

        let otel = MockEmbraceOpenTelemetry()

        // given a crash reporter
        let crashReporter = CrashReporterMock(crashSessionId: TestConstants.sessionId.toString)
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

        // then a crash report request was attempted
        // then a session request was attempted
        XCTAssert(EmbraceHTTPMock.requestsForUrl(self.testLogsUrl()).count > 0)
        XCTAssert(EmbraceHTTPMock.requestsForUrl(self.testSpansUrl()).count > 0)

        // then the total amount of requests is correct
        XCTAssertEqual(EmbraceHTTPMock.totalRequestCount(), 2)

        // then the session is no longer on storage
        let session = storage.fetchSession(id: TestConstants.sessionId)
        XCTAssertNil(session)

        // then the session and crash report upload data are still cached
        let uploadData = upload.cache.fetchAllUploadData()
        XCTAssertEqual(uploadData.count, 2)

        // then the crash is not longer stored
        let reports = await crashReporter.fetchUnsentCrashReports()
        XCTAssertEqual(reports.count, 0)

        // then the raw crash log was sent
        XCTAssertEqual(otel.logs.count, 1)
        XCTAssertEqual(otel.logs[0].attributes["emb.type"], .string(LogType.crash.rawValue))
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
            options: uploadOptions, logger: logger, queue: queue, semaphore: .init(value: .max))

        let otel = MockEmbraceOpenTelemetry()

        // given a crash reporter
        let crashReporter = CrashReporterMock(crashSessionId: TestConstants.sessionId.toString)
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
        XCTAssertEqual(otel.logs[0].attributes["emb.type"], .string(LogType.crash.rawValue))
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
            options: uploadOptions, logger: logger, queue: queue, semaphore: .init(value: .max))
        let otel = MockEmbraceOpenTelemetry()

        // given a crash reporter
        let crashReporter = CrashReporterMock(crashSessionId: TestConstants.sessionId.toString)
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

        // then a crash log was sent
        XCTAssert(EmbraceHTTPMock.requestsForUrl(self.testLogsUrl()).count > 0)

        // then the total amount of requests is correct
        XCTAssertEqual(EmbraceHTTPMock.totalRequestCount(), 1)

        // then the crash log upload data is no longer cached
        let uploadData = upload.cache.fetchAllUploadData()
        XCTAssertEqual(uploadData.count, 0)

        // then the raw crash log was constructed correctly
        XCTAssertEqual(otel.logs.count, 1)
        XCTAssertEqual(otel.logs[0].attributes["emb.type"], .string(LogType.crash.rawValue))
        XCTAssertEqual(otel.logs[0].timestamp, report.timestamp)
        XCTAssertEqual(otel.logs[0].body?.description, "")
        XCTAssertEqual(otel.logs[0].severity, .fatal)
        XCTAssertEqual(otel.logs[0].attributes["session.id"], .string(TestConstants.sessionId.toString))
        XCTAssertEqual(otel.logs[0].attributes["emb.state"], .string(SessionState.foreground.rawValue))
        XCTAssertEqual(otel.logs[0].attributes["log.record.uid"], .string(report.id.withoutHyphen))
        XCTAssertEqual(otel.logs[0].attributes["emb.provider"], .string(report.provider))
        XCTAssertEqual(otel.logs[0].attributes["emb.payload"], .string(report.payload))
    }

    func test_spanCleanUp_sendUnsentData() async throws {
        // mock successful requests
        EmbraceHTTPMock.mock(url: testSpansUrl())
        EmbraceHTTPMock.mock(url: testLogsUrl())

        // given a storage and upload modules
        let storage = try EmbraceStorage.createInMemoryDb()
        defer { storage.coreData.destroy() }

        let upload = try EmbraceUpload(
            options: uploadOptions, logger: logger, queue: queue, semaphore: .init(value: .max))

        let otel = MockEmbraceOpenTelemetry()

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
            id: "oldSpan",
            name: "test",
            traceId: "traceId",
            type: .performance,
            data: Data(),
            startTime: Date(timeIntervalSinceNow: -100),
            endTime: Date(timeIntervalSinceNow: -80)
        )

        // given open span in storage
        storage.upsertSpan(
            id: TestConstants.spanId,
            name: "test",
            traceId: TestConstants.traceId,
            type: .performance,
            data: Data(),
            startTime: Date(timeIntervalSinceNow: -50),
            processId: TestConstants.processId
        )

        // when sending unsent sessions
        await UnsentDataHandler.sendUnsentData(storage: storage, upload: upload, otel: otel)

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
            options: uploadOptions, logger: logger, queue: queue, semaphore: .init(value: .max))

        let otel = MockEmbraceOpenTelemetry()

        // given an unfinished session in the storage
        await storage.addSession(
            id: TestConstants.sessionId,
            processId: ProcessIdentifier.current,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date(timeIntervalSinceNow: -60)
        )

        // given metadata in storage
        storage.addMetadata(
            key: "permanent",
            value: "test",
            type: .requiredResource,
            lifespan: .permanent
        )
        storage.addMetadata(
            key: "sameSessionId",
            value: "test",
            type: .requiredResource,
            lifespan: .session,
            lifespanId: TestConstants.sessionId.toString
        )
        storage.addMetadata(
            key: "sameProcessId",
            value: "test",
            type: .requiredResource,
            lifespan: .process,
            lifespanId: ProcessIdentifier.current.value
        )
        storage.addMetadata(
            key: "differentSessionId",
            value: "test",
            type: .requiredResource,
            lifespan: .session,
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
            currentSessionId: TestConstants.sessionId
        )

        // then all metadata is cleaned up
        let records: [MetadataRecord] = storage.fetchAll()
        XCTAssertNotNil(records.first(where: { $0.key == "permanent" }))
        XCTAssertNotNil(records.first(where: { $0.key == "sameSessionId" }))
        XCTAssertNotNil(records.first(where: { $0.key == "sameProcessId" }))
        XCTAssertNil(records.first(where: { $0.key == "differentSessionId" }))
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
            options: uploadOptions, logger: logger, queue: queue, semaphore: .init(value: .max))

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
            id: "oldSpan",
            name: "test",
            traceId: "traceId",
            type: .performance,
            data: Data(),
            startTime: Date(timeIntervalSinceNow: -100),
            endTime: Date(timeIntervalSinceNow: -80)
        )

        // when uploading the session
        await UnsentDataHandler.sendSession(session, storage: storage, upload: upload)

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
            options: uploadOptions, logger: logger, queue: queue, semaphore: .init(value: .max))

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
            lifespanId: ProcessIdentifier.current.value
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
            options: uploadOptions, logger: logger, queue: queue, semaphore: .init(value: .max))
        let logController = LogController(
            storage: storage,
            upload: upload,
            controller: MockSessionController()
        )
        logController.sdkStateProvider = sdkStateProvider
        let otel = MockEmbraceOpenTelemetry()

        // given logs in storage
        for _ in 0...5 {
            storage.createLog(
                id: LogIdentifier.random,
                processId: TestConstants.processId,
                severity: .debug,
                body: "test",
                attributes: [:]
            )
        }

        // when sending unsent data
        await UnsentDataHandler.sendUnsentData(
            storage: storage, upload: upload, otel: otel, logController: logController)

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
            options: uploadOptions, logger: logger, queue: queue, semaphore: .init(value: .max))

        // given critical logs file present
        try "TEST".write(to: criticalLogsFilePath, atomically: true, encoding: .utf8)

        // when sending critical logs
        await UnsentDataHandler.sendCriticalLogs(fileUrl: criticalLogsFilePath, upload: upload)

        // then a log is sent
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(testLogsUrl()).count, 1)
    }

    func test_criticalLogs_noFile() async throws {
        // mock successful requests
        EmbraceHTTPMock.mock(url: testLogsUrl())

        // given upload module
        let upload = try EmbraceUpload(
            options: uploadOptions, logger: logger, queue: queue, semaphore: .init(value: .max))

        // when sending critical logs without a file present
        await UnsentDataHandler.sendCriticalLogs(fileUrl: criticalLogsFilePath, upload: upload)

        // then no log is sent
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(testLogsUrl()).count, 0)
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
    public func addSession(
        id: SessionIdentifier,
        processId: ProcessIdentifier,
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
