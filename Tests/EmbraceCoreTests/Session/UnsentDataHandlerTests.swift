//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import XCTest
@testable import EmbraceCore
import EmbraceCommonInternal
@testable import EmbraceStorageInternal
@testable import EmbraceUploadInternal
import TestSupport
import GRDB

class UnsentDataHandlerTests: XCTestCase {
    let logger = MockLogger()
    let filePathProvider = TemporaryFilepathProvider()
    var context: CrashReporterContext!
    var uploadOptions: EmbraceUpload.Options!
    var queue: DispatchQueue!

    static let testRedundancyOptions = EmbraceUpload.RedundancyOptions(automaticRetryCount: 0)
    static let testMetadataOptions = EmbraceUpload.MetadataOptions(
        apiKey: "apiKey",
        userAgent: "userAgent",
        deviceId: "12345678"
    )

    override func setUpWithError() throws {
        // delete tmpdir
        try? FileManager.default.removeItem(at: filePathProvider.tmpDirectory)

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
            cache: EmbraceUpload.CacheOptions(named: testName),
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

    func test_withoutCrashReporter() throws {
        // mock successful requests
        EmbraceHTTPMock.mock(url: testSpansUrl())

        // given a storage and upload modules
        let storage = try EmbraceStorage.createInMemoryDb()
        defer { try? storage.teardown() }

        let upload = try EmbraceUpload(options: uploadOptions, logger: logger, queue: queue)

        let otel = MockEmbraceOpenTelemetry()

        // given a finished session in the storage
        try storage.addSession(
            id: TestConstants.sessionId,
            state: .foreground,
            processId: ProcessIdentifier.current,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date(timeIntervalSinceNow: -60),
            endTime: Date()
        )

        // when sending unsent sessions
        UnsentDataHandler.sendUnsentData(storage: storage, upload: upload, otel: otel, crashReporter: nil)
        wait(delay: .longTimeout)

        // then a session request was sent
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(testSpansUrl()).count, 1)

        // then the session is no longer on storage
        let session = try storage.fetchSession(id: TestConstants.sessionId)
        XCTAssertNil(session)

        // then the session upload data is no longer cached
        let uploadData = try upload.cache.fetchAllUploadData()
        XCTAssertEqual(uploadData.count, 0)

        // then no log was sent
        XCTAssertEqual(otel.logs.count, 0)
    }

    func test_withoutCrashReporter_error() throws {
        // mock error requests
        EmbraceHTTPMock.mock(url: testSpansUrl(), errorCode: 500)

        // given a storage and upload modules
        let storage = try EmbraceStorage.createInMemoryDb()
        defer { try? storage.teardown() }

        let upload = try EmbraceUpload(options: uploadOptions, logger: logger, queue: queue)

        let otel = MockEmbraceOpenTelemetry()

        // given a finished session in the storage
        try storage.addSession(
            id: TestConstants.sessionId,
            state: .foreground,
            processId: ProcessIdentifier.current,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date(timeIntervalSinceNow: -60),
            endTime: Date()
        )

        // when failing to send unsent sessions
        UnsentDataHandler.sendUnsentData(storage: storage, upload: upload, otel: otel, crashReporter: nil)
        wait(delay: .longTimeout)

        // then a session request was attempted
        XCTAssertGreaterThan(EmbraceHTTPMock.requestsForUrl(testSpansUrl()).count, 0)

        // then the total amount of requests is correct
        XCTAssertEqual(EmbraceHTTPMock.totalRequestCount(), 1)

        // then the session is no longer on storage
        let session = try storage.fetchSession(id: TestConstants.sessionId)
        XCTAssertNil(session)

        // then the session upload data cached
        let uploadData = try upload.cache.fetchAllUploadData()
        XCTAssertEqual(uploadData.count, 1)

        // then no log was sent
        XCTAssertEqual(otel.logs.count, 0)
    }

    func test_withCrashReporter() throws {
        // mock successful requests
        EmbraceHTTPMock.mock(url: testSpansUrl())
        EmbraceHTTPMock.mock(url: testLogsUrl())

        // given a storage and upload modules
        let storage = try EmbraceStorage.createInMemoryDb()
        defer { try? storage.teardown() }

        let upload = try EmbraceUpload(options: uploadOptions, logger: logger, queue: queue)

        let otel = MockEmbraceOpenTelemetry()

        // given a crash reporter
        let crashReporter = CrashReporterMock(crashSessionId: TestConstants.sessionId.toString)
        let report = crashReporter.mockReports[0]

        // given a finished session in the storage
        try storage.addSession(
            id: TestConstants.sessionId,
            state: .foreground,
            processId: ProcessIdentifier.current,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date(timeIntervalSinceNow: -60),
            endTime: Date()
        )

        // when sending unsent sessions
        UnsentDataHandler.sendUnsentData(storage: storage, upload: upload, otel: otel, crashReporter: crashReporter)

        // then the crash report id is set on the session
        let expectation1 = XCTestExpectation()
        let observation = ValueObservation.tracking(SessionRecord.fetchAll)
        let cancellable = observation.start(in: storage.dbQueue) { error in
            XCTAssert(false, error.localizedDescription)
        } onChange: { records in
            if let record = records.first {
                if record.crashReportId != nil {
                    expectation1.fulfill()
                }
            }
        }
        wait(for: [expectation1], timeout: .veryLongTimeout)
        cancellable.cancel()

        // then a crash report was sent
        // then a session request was sent
        wait(timeout: .veryLongTimeout) {
            EmbraceHTTPMock.requestsForUrl(self.testLogsUrl()).count == 1 &&
            EmbraceHTTPMock.requestsForUrl(self.testSpansUrl()).count == 1
        }

        // then the total amount of requests is correct
        XCTAssertEqual(EmbraceHTTPMock.totalRequestCount(), 2)

        // then the session is no longer on storage
        let session = try storage.fetchSession(id: TestConstants.sessionId)
        XCTAssertNil(session)

        // then the session and crash report upload data is no longer cached
        let uploadData = try upload.cache.fetchAllUploadData()
        XCTAssertEqual(uploadData.count, 0)

        // then the crash is not longer stored
        let expectation = XCTestExpectation()
        crashReporter.fetchUnsentCrashReports { reports in
            XCTAssertEqual(reports.count, 0)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)

        // then the raw crash log was sent
        XCTAssertEqual(otel.logs.count, 1)
        XCTAssertEqual(otel.logs[0].attributes["emb.type"], .string(LogType.crash.rawValue))
        XCTAssertEqual(otel.logs[0].timestamp, report.timestamp)

        // clean up
        cancellable.cancel()
    }

    func test_withCrashReporter_error() throws {
        EmbraceHTTPMock.mock(url: testSpansUrl(), errorCode: 500)
        EmbraceHTTPMock.mock(url: testLogsUrl(), errorCode: 500)

        // given a storage and upload modules
        let storage = try EmbraceStorage.createInMemoryDb()
        defer { try? storage.teardown() }

        let upload = try EmbraceUpload(options: uploadOptions, logger: logger, queue: queue)

        let otel = MockEmbraceOpenTelemetry()

        // given a crash reporter
        let crashReporter = CrashReporterMock(crashSessionId: TestConstants.sessionId.toString)
        let report = crashReporter.mockReports[0]

        // then the crash report id is set on the session
        let didSendCrashesExpectation = XCTestExpectation()
        let observation = ValueObservation.tracking(SessionRecord.fetchAll)
        let cancellable = observation.start(in: storage.dbQueue) { error in
            XCTAssert(false, error.localizedDescription)
        } onChange: { records in
            if let record = records.first {
                if record.crashReportId != nil {
                    didSendCrashesExpectation.fulfill()
                }
            }
        }

        // given a finished session in the storage
        try storage.addSession(
            id: TestConstants.sessionId,
            state: .foreground,
            processId: ProcessIdentifier.current,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date(timeIntervalSinceNow: -60),
            endTime: Date()
        )

        // when failing to send unsent sessions
        UnsentDataHandler.sendUnsentData(storage: storage, upload: upload, otel: otel, crashReporter: crashReporter)

        wait(for: [didSendCrashesExpectation], timeout: .veryLongTimeout)
        cancellable.cancel()

        // then a crash report request was attempted
        // then a session request was attempted
        wait(timeout: .veryLongTimeout) {
            EmbraceHTTPMock.requestsForUrl(self.testLogsUrl()).count > 0 &&
            EmbraceHTTPMock.requestsForUrl(self.testSpansUrl()).count > 0
        }

        // then the total amount of requests is correct
        XCTAssertEqual(EmbraceHTTPMock.totalRequestCount(), 2)

        // then the session is no longer on storage
        let session = try storage.fetchSession(id: TestConstants.sessionId)
        XCTAssertNil(session)

        // then the session and crash report upload data are still cached
        let uploadData = try upload.cache.fetchAllUploadData()
        XCTAssertEqual(uploadData.count, 2)

        // then the crash is not longer stored
        let expectation = XCTestExpectation()
        crashReporter.fetchUnsentCrashReports { reports in
            XCTAssertEqual(reports.count, 0)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)

        // then the raw crash log was sent
        XCTAssertEqual(otel.logs.count, 1)
        XCTAssertEqual(otel.logs[0].attributes["emb.type"], .string(LogType.crash.rawValue))
        XCTAssertEqual(otel.logs[0].timestamp, report.timestamp)
    }

    func test_withCrashReporter_unfinishedSession() throws {
        // mock successful requests
        EmbraceHTTPMock.mock(url: testSpansUrl())
        EmbraceHTTPMock.mock(url: testLogsUrl())

        // given a storage and upload modules
        let storage = try EmbraceStorage.createInMemoryDb()
        defer { try? storage.teardown() }

        let upload = try EmbraceUpload(options: uploadOptions, logger: logger, queue: queue)

        let otel = MockEmbraceOpenTelemetry()

        // given a crash reporter
        let crashReporter = CrashReporterMock(crashSessionId: TestConstants.sessionId.toString)
        let report = crashReporter.mockReports[0]

        // given an unfinished session in the storage
        try storage.addSession(
            id: TestConstants.sessionId,
            state: .foreground,
            processId: ProcessIdentifier.current,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date(timeIntervalSinceNow: -60)
        )

        // the crash report id and timestamp is set on the session
        let expectation1 = XCTestExpectation()
        let observation = ValueObservation.tracking(SessionRecord.fetchAll).print()
        let cancellable = observation.start(in: storage.dbQueue) { error in
            XCTAssert(false, error.localizedDescription)
        } onChange: { records in
            if let record = records.first {
                if record.crashReportId != nil && record.endTime != nil {
                    expectation1.fulfill()
                }
            }
        }

        // when sending unsent sessions
        UnsentDataHandler.sendUnsentData(storage: storage, upload: upload, otel: otel, crashReporter: crashReporter)

        wait(for: [expectation1], timeout: 5000)
        cancellable.cancel()

        // then a crash report was sent
        // then a session request was sent
        wait(timeout: .veryLongTimeout) {
            EmbraceHTTPMock.requestsForUrl(self.testLogsUrl()).count == 1 &&
            EmbraceHTTPMock.requestsForUrl(self.testSpansUrl()).count == 1
        }

        // then the total amount of requests is correct
        XCTAssertEqual(EmbraceHTTPMock.totalRequestCount(), 2)

        // then the session is no longer on storage
        let session = try storage.fetchSession(id: TestConstants.sessionId)
        XCTAssertNil(session)

        // then the session and crash report upload data is no longer cached
        wait(timeout: .veryLongTimeout) {
            try upload.cache.fetchAllUploadData().count == 0
        }

        let expectation = XCTestExpectation()
        crashReporter.fetchUnsentCrashReports { reports in
            XCTAssertEqual(reports.count, 0)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)

        // then the raw crash log was sent
        XCTAssertEqual(otel.logs.count, 1)
        XCTAssertEqual(otel.logs[0].attributes["emb.type"], .string(LogType.crash.rawValue))
        XCTAssertEqual(otel.logs[0].timestamp, report.timestamp)

        // clean up
        cancellable.cancel()
    }

    func test_sendCrashLog() throws {
        // mock successful requests
        EmbraceHTTPMock.mock(url: testLogsUrl())

        // given a storage and upload modules
        let storage = try EmbraceStorage.createInMemoryDb()
        defer { try? storage.teardown() }

        let upload = try EmbraceUpload(options: uploadOptions, logger: logger, queue: queue)
        let otel = MockEmbraceOpenTelemetry()

        // given a crash reporter
        let crashReporter = CrashReporterMock(crashSessionId: TestConstants.sessionId.toString)
        let report = crashReporter.mockReports[0]

        // given a finished session in the storage
        let session = try storage.addSession(
            id: TestConstants.sessionId,
            state: .foreground,
            processId: ProcessIdentifier.current,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date(timeIntervalSinceNow: -60),
            endTime: Date()
        )

        // when sending a crash log
        UnsentDataHandler.sendCrashLog(
            report: report,
            reporter: crashReporter,
            session: session,
            storage: storage,
            upload: upload,
            otel: otel
        )

        // then a crash log was sent
        wait(timeout: .veryLongTimeout) {
            EmbraceHTTPMock.requestsForUrl(self.testLogsUrl()).count > 0
        }

        // then the total amount of requests is correct
        XCTAssertEqual(EmbraceHTTPMock.totalRequestCount(), 1)

        // then the crash log upload data is no longer cached
        let uploadData = try upload.cache.fetchAllUploadData()
        XCTAssertEqual(uploadData.count, 0)

        // then the raw crash log was constructed correctly
        XCTAssertEqual(otel.logs.count, 1)
        XCTAssertEqual(otel.logs[0].attributes["emb.type"], .string(LogType.crash.rawValue))
        XCTAssertEqual(otel.logs[0].timestamp, report.timestamp)
        XCTAssertEqual(otel.logs[0].body?.description, "")
        XCTAssertEqual(otel.logs[0].severity, .fatal4)
        XCTAssertEqual(otel.logs[0].attributes["emb.session_id"], .string(TestConstants.sessionId.toString))
        XCTAssertEqual(otel.logs[0].attributes["emb.state"], .string(SessionState.foreground.rawValue))
        XCTAssertEqual(otel.logs[0].attributes["log.record.uid"], .string(report.id.withoutHyphen))
        XCTAssertEqual(otel.logs[0].attributes["emb.provider"], .string(report.provider))
        XCTAssertEqual(otel.logs[0].attributes["emb.payload"], .string(report.payload))
    }

    func test_spanCleanUp_sendUnsentData() throws {
        // mock successful requests
        EmbraceHTTPMock.mock(url: testSpansUrl())
        EmbraceHTTPMock.mock(url: testLogsUrl())

        // given a storage and upload modules
        let storage = try EmbraceStorage.createInMemoryDb()
        defer { try? storage.teardown() }

        let upload = try EmbraceUpload(options: uploadOptions, logger: logger, queue: queue)

        let otel = MockEmbraceOpenTelemetry()

        // given an unfinished session in the storage
        try storage.addSession(
            id: TestConstants.sessionId,
            state: .foreground,
            processId: ProcessIdentifier.current,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date(timeIntervalSinceNow: -60)
        )

        // given old closed span in storage
        let oldSpan = try storage.addSpan(
            id: "oldSpan",
            name: "test",
            traceId: "traceId",
            type: .performance,
            data: Data(),
            startTime: Date(timeIntervalSinceNow: -100),
            endTime: Date(timeIntervalSinceNow: -80)
        )

        // given open span in storage
        _ = try storage.addSpan(
            id: TestConstants.spanId,
            name: "test",
            traceId: TestConstants.traceId,
            type: .performance,
            data: Data(),
            startTime: Date(timeIntervalSinceNow: -50),
            processIdentifier: TestConstants.processId
        )

        // when sending unsent sessions
        UnsentDataHandler.sendUnsentData(storage: storage, upload: upload, otel: otel)
        wait(delay: .longTimeout)

        // then the old closed span was removed
        // and the open span was closed
        let expectation1 = XCTestExpectation()
        try storage.dbQueue.read { db in
            XCTAssertFalse(try oldSpan.exists(db))

            let span = try SpanRecord.fetchOne(db)
            XCTAssertEqual(span!.id, TestConstants.spanId)
            XCTAssertEqual(span!.traceId, TestConstants.traceId)
            XCTAssertNotNil(span!.endTime)

            expectation1.fulfill()
        }

        wait(for: [expectation1], timeout: .defaultTimeout)

        // when sending unsent sessions again
        UnsentDataHandler.sendUnsentData(storage: storage, upload: upload, otel: otel)

        // then the span that was closed for the last session
        // is not valid anymore, and therefore removed
        let expectation2 = XCTestExpectation()
        try storage.dbQueue.read { db in
            XCTAssertEqual(try SpanRecord.fetchCount(db), 0)
            expectation2.fulfill()
        }

        wait(for: [expectation2], timeout: .defaultTimeout)
    }

    func test_metadataCleanUp_sendUnsendData() throws {
        // mock successful requests
        EmbraceHTTPMock.mock(url: testSpansUrl())
        EmbraceHTTPMock.mock(url: testLogsUrl())

        // given a storage and upload modules
        let storage = try EmbraceStorage.createInMemoryDb()
        defer { try? storage.teardown() }

        let upload = try EmbraceUpload(options: uploadOptions, logger: logger, queue: queue)

        let otel = MockEmbraceOpenTelemetry()

        // given an unfinished session in the storage
        try storage.addSession(
            id: TestConstants.sessionId,
            state: .foreground,
            processId: ProcessIdentifier.current,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date(timeIntervalSinceNow: -60)
        )

        // given metadata in storage
        let permanentMetadata = try storage.addMetadata(
            key: "test",
            value: "test",
            type: .requiredResource,
            lifespan: .permanent
        )
        let sameSessionId = try storage.addMetadata(
            key: "test",
            value: "test",
            type: .requiredResource,
            lifespan: .session,
            lifespanId: TestConstants.sessionId.toString
        )
        let sameProcessId = try storage.addMetadata(
            key: "test",
            value: "test",
            type: .requiredResource,
            lifespan: .process,
            lifespanId: ProcessIdentifier.current.hex
        )
        let differentSessionId = try storage.addMetadata(
            key: "test",
            value: "test",
            type: .requiredResource,
            lifespan: .session,
            lifespanId: "test"
        )
        let differentProcessId = try storage.addMetadata(
            key: "test",
            value: "test",
            type: .requiredResource,
            lifespan: .process,
            lifespanId: "test"
        )

        // when sending unsent sessions
        UnsentDataHandler.sendUnsentData(
            storage: storage,
            upload: upload,
            otel: otel,
            currentSessionId: TestConstants.sessionId
        )

        // then all metadata is cleaned up
        let expectation = XCTestExpectation()
        try storage.dbQueue.read { db in
            XCTAssert(try permanentMetadata!.exists(db))
            XCTAssert(try sameSessionId!.exists(db))
            XCTAssert(try sameProcessId!.exists(db))
            XCTAssertFalse(try differentSessionId!.exists(db))
            XCTAssertFalse(try differentProcessId!.exists(db))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_spanCleanUp_uploadSession() throws {
        // mock successful requests
        EmbraceHTTPMock.mock(url: testSpansUrl())
        EmbraceHTTPMock.mock(url: testLogsUrl())

        // given a storage and upload modules
        let storage = try EmbraceStorage.createInMemoryDb()
        defer { try? storage.teardown() }

        let upload = try EmbraceUpload(options: uploadOptions, logger: logger, queue: queue)

        // given an unfinished session in the storage
        let session = try storage.addSession(
            id: TestConstants.sessionId,
            state: .foreground,
            processId: ProcessIdentifier.current,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date(timeIntervalSinceNow: -60)
        )

        // given old closed span in storage
        let oldSpan = try storage.addSpan(
            id: "oldSpan",
            name: "test",
            traceId: "traceId",
            type: .performance,
            data: Data(),
            startTime: Date(timeIntervalSinceNow: -100),
            endTime: Date(timeIntervalSinceNow: -80)
        )

        // when uploading the session
        UnsentDataHandler.sendSession(session, storage: storage, upload: upload)
        wait(delay: .longTimeout)

        // then the old closed span was removed
        // and the session was removed
        let expectation = XCTestExpectation()
        try storage.dbQueue.read { db in
            XCTAssertFalse(try oldSpan.exists(db))
            XCTAssertEqual(try SpanRecord.fetchCount(db), 0)

            XCTAssertFalse(try session.exists(db))
            XCTAssertEqual(try SessionRecord.fetchCount(db), 0)

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_metadataCleanUp_uploadSession() throws {
        // mock successful requests
        EmbraceHTTPMock.mock(url: testSpansUrl())
        EmbraceHTTPMock.mock(url: testLogsUrl())

        // given a storage and upload modules
        let storage = try EmbraceStorage.createInMemoryDb()
        defer { try? storage.teardown() }

        let upload = try EmbraceUpload(options: uploadOptions, logger: logger, queue: queue)

        // given an unfinished session in the storage
        let session = try storage.addSession(
            id: TestConstants.sessionId,
            state: .foreground,
            processId: ProcessIdentifier.current,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date(timeIntervalSinceNow: -60)
        )

        // given metadata in storage
        let permanentMetadata = try storage.addMetadata(
            key: "test",
            value: "test",
            type: .requiredResource,
            lifespan: .permanent
        )
        let sameProcessId = try storage.addMetadata(
            key: "test",
            value: "test",
            type: .requiredResource,
            lifespan: .process,
            lifespanId: ProcessIdentifier.current.hex
        )
        let differentProcessId = try storage.addMetadata(
            key: "test",
            value: "test",
            type: .requiredResource,
            lifespan: .process,
            lifespanId: "test"
        )

        // when uploading the session
        UnsentDataHandler.sendSession(session, storage: storage, upload: upload)
        wait(delay: .longTimeout)

        // then metadata is correctly cleaned up
        let expectation = XCTestExpectation()
        try storage.dbQueue.read { db in
            XCTAssert(try permanentMetadata!.exists(db))
            XCTAssert(try sameProcessId!.exists(db))
            XCTAssertFalse(try differentProcessId!.exists(db))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_logsUpload() throws {
        // mock successful requests
        EmbraceHTTPMock.mock(url: testSpansUrl())
        EmbraceHTTPMock.mock(url: testLogsUrl())

        // given a storage and upload modules
        let storage = try EmbraceStorage.createInMemoryDb()
        defer { try? storage.teardown() }

        let upload = try EmbraceUpload(options: uploadOptions, logger: logger, queue: queue)
        let logController = LogController(storage: storage, upload: upload, controller: MockSessionController())
        let otel = MockEmbraceOpenTelemetry()

        // given logs in storage
        for _ in 0...5 {
            try storage.writeLog(LogRecord(
                identifier: LogIdentifier.random,
                processIdentifier: TestConstants.processId,
                severity: .debug,
                body: "test",
                attributes: [:]
            ))
        }

        // when sending unsent data
        UnsentDataHandler.sendUnsentData(storage: storage, upload: upload, otel: otel, logController: logController)
        wait(delay: .longTimeout)

        // then no sessions were sent
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(testSpansUrl()).count, 0)

        // then a log batch was sent
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(testLogsUrl()).count, 1)
    }
}

private extension UnsentDataHandlerTests {
    func testEndpointOptions(forTest testName: String) -> EmbraceUpload.EndpointOptions {
        .init(
            spansURL: testSpansUrl(forTest: testName),
            logsURL: testLogsUrl(forTest: testName)
        )
    }

    func testSpansUrl(forTest testName: String = #function) -> URL {
        var url = URL(string: "https://embrace.test.com/sessions")!
        url.testName = testName
        return url
    }

    func testLogsUrl(forTest testName: String = #function) -> URL {
        var url = URL(string: "https://embrace.test.com/logs")!
        url.testName = testName
        return url
    }
}
