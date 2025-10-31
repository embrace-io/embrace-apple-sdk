//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceConfigInternal
import EmbraceSemantics
import EmbraceStorageInternal
import EmbraceUploadInternal
import TestSupport
import XCTest

@testable import EmbraceCore

class LogControllerTests: XCTestCase {
    private var sut: LogController!
    private var storage: SpyStorage?
    private var sessionController: MockSessionController!
    private var upload: SpyEmbraceLogUploader!
    private let sdkStateProvider = MockEmbraceSDKStateProvider()
    private let loggingQueue = DispatchQueue(label: "loggingQueue")

    override func setUp() {
        givenEmbraceLogUploader()
        givenSDKEnabled()
        givenSessionControllerWithSession()
        givenStorage()
    }

    // MARK: - Testing `setup` method

    func testOnNotHavingStorage_onSetup_wontDoAnything() {
        givenLogControllerWithNoStorage()
        whenInvokingSetup()
        thenDoesntTryToUploadAnything()
    }

    func test_onSetup_fetchesAllLogsExcludingTheOnesWithCurrentProcessIdentifier() throws {
        givenLogController()
        whenInvokingSetup()
        try thenFetchesAllLogsExcluding(pid: ProcessIdentifier.current)
    }

    func testHavingNoLogs_onSetup_wontTryToUploadAnything() {
        givenLogController()
        whenInvokingSetup()
        thenDoesntTryToUploadAnything()
    }

    func testHavingLogs_onSetup_fetchesResourcesFromStorage() throws {
        let sessionId = EmbraceIdentifier.random
        let log = randomLogRecord(sessionId: sessionId)

        givenStorage(withLogs: [log])
        givenLogController()
        whenInvokingSetup()
        try thenFetchesResourcesFromStorage(sessionId: sessionId)
    }

    func testHavingLogs_onSetup_fetchesMetadataFromStorage() throws {
        let sessionId = EmbraceIdentifier.random
        let log = randomLogRecord(sessionId: sessionId)

        givenStorage(withLogs: [log])
        givenLogController()
        whenInvokingSetup()
        try thenFetchesMetadataFromStorage(sessionId: sessionId)
    }

    func testHavingLogsWithNoSessionId_onSetup_fetchesResourcesFromStorage() throws {
        let log = randomLogRecord()
        givenStorage(withLogs: [log])
        givenLogController()
        whenInvokingSetup()
        try thenFetchesResourcesFromStorage(processId: log.processId)
    }

    func testHavingLogsWithNoSessionId_onSetup_fetchesMetadataFromStorage() throws {
        let log = randomLogRecord()
        givenStorage(withLogs: [log])
        givenLogController()
        whenInvokingSetup()
        try thenFetchesMetadataFromStorage(processId: log.processId)
    }

    func testHavingLogsForLessThanABatch_onSetup_logUploaderShouldSendASingleBatch() {
        givenStorage(withLogs: [randomLogRecord(), randomLogRecord()])
        givenLogController()
        whenInvokingSetup()
        thenLogUploadShouldUpload(times: 1)
    }

    func testSDKDisabledHavingLogsForLessThanABatch_onSetup_logUploaderShouldntSendASingleBatch() throws {
        givenStorage(withLogs: [randomLogRecord(), randomLogRecord()])
        givenSDKEnabled(false)
        givenLogController()
        whenInvokingSetup()
        thenLogUploadShouldUpload(times: 0)
        try thenStorageShouldntCallRemoveLogs()
    }

    func testHavingLogsForMoreThanABatch_onSetup_logUploaderShouldSendTwoBatches() {
        givenStorage(withLogs: logsForMoreThanASingleBatch())
        givenLogController()
        whenInvokingSetup()
        thenLogUploadShouldUpload(times: 2)
    }

    func testOnSuccefullyPushingBatch_onSetup_shouldRemoveLogs() throws {
        let logRecord = randomLogRecord()
        givenStorage(withLogs: [logRecord])
        givenLogController()
        whenInvokingSetup()
        thenLogUploaderShouldSendLogs()
        try thenStorageShouldCallRemove(withLogs: [logRecord])
    }

    func testOnFailingPushingBatch_onSetup_shouldntRemoveLogs() throws {
        let logRecord = randomLogRecord()
        givenFailingLogUploader()
        givenStorage(withLogs: [logRecord])
        givenLogController()
        whenInvokingSetup()
        thenLogUploaderShouldSendLogs()
        try thenStorageShouldntCallRemoveLogs()
    }

    // MARK: - Testing `batchFinished` method

    func testHavingLogsButNoSession_onBatchFinished_wontTryToUploadAnything() {
        givenSessionControllerWithoutSession()
        givenLogController()
        whenInvokingBatchFinished(withLogs: [randomLogRecord()])
        thenDoesntTryToUploadAnything()
    }

    func testHavingSessionButNoLogs_onBatchFinished_wontTryToUploadAnything() {
        givenLogController()
        whenInvokingBatchFinished(withLogs: [])
        thenDoesntTryToUploadAnything()
    }

    func testHavingLogs_onBatchFinished_fetchesResourcesFromStorage() throws {
        givenLogController()
        whenInvokingBatchFinished(withLogs: [randomLogRecord()])
        try thenFetchesResourcesFromStorage(sessionId: sessionController.currentSession?.id)
    }

    func testHavingLogs_onBatchFinished_fetchesMetadataFromStorage() throws {
        givenLogController()
        whenInvokingBatchFinished(withLogs: [randomLogRecord()])
        try thenFetchesMetadataFromStorage(sessionId: sessionController.currentSession?.id)
    }

    func testHavingLogs_onBatchFinished_logUploaderShouldSendASingleBatch() throws {
        givenLogController()
        whenInvokingBatchFinished(withLogs: [randomLogRecord()])
        try thenFetchesMetadataFromStorage(sessionId: sessionController.currentSession?.id)
    }

    func testSDKDisabledHavingLogs_onBatchFinished_ontTryToUploadAnything() throws {
        givenSDKEnabled(false)
        givenLogController()
        whenInvokingBatchFinished(withLogs: [randomLogRecord()])
        thenDoesntTryToUploadAnything()
    }

    func test_onBatchFinishedReceivingLogsAmountLargerThanBatch_logUploaderShouldSendASingleBatch() {
        givenLogController()
        let logs = (0...(sut.batcher.logBatchLimits.maxLogsPerBatch + 5)).map { _ in randomLogRecord() }
        whenInvokingBatchFinished(withLogs: logs)
        thenLogUploadShouldUpload(times: 1)
    }

    func test_batchPayloadTypes() {
        givenStorage(withLogs: [
            randomLogRecord(type: "test"),
            randomLogRecord(type: "test"),
            randomLogRecord(type: "type"),
            randomLogRecord(type: "sys.log")
        ])
        givenLogController()
        whenInvokingSetup()
        thenLogUploadShouldUpload(times: 1)
        thenPayloadTypesIsSet(["test", "type", "sys.log"])
    }

    // MARK: LogController.Error tests
    func test_errorAsNSError_shouldProvideValuesForEachCase() {
        let allCases = [
            LogController.Error.couldntAccessBatches(reason: UUID().uuidString),
            LogController.Error.couldntCreatePayload(reason: UUID().uuidString),
            LogController.Error.couldntUpload(reason: UUID().uuidString),
            LogController.Error.couldntAccessStorageModule,
            LogController.Error.couldntAccessUploadModule
        ]
        allCases.forEach {
            let convertedError = $0 as NSError
            XCTAssertEqual(convertedError.domain, "Embrace")
            XCTAssertNotEqual(convertedError.code, 0)
            XCTAssertTrue(convertedError.userInfo.isEmpty)
        }
    }

    // MARK: - createLog
    func test_createLog() throws {
        givenLogController()

        let expectation = XCTestExpectation()
        whenCreatingLog { log in
            self.thenLogIsCreatedCorrectly(log!)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_createLogWithAttachment_success() throws {
        givenEmbraceLogUploader()
        givenLogController()

        let expectation = XCTestExpectation()
        whenCreatingLogWithAttachment { log in
            self.thenLogWithSuccessfulAttachmentIsCreatedCorrectly(log!)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_createLogWithAttachment_tooLarge() throws {
        givenEmbraceLogUploader()
        givenLogController()

        let expectation = XCTestExpectation()
        whenCreatingLogWithBigAttachment { log in
            self.thenLogWithUnsuccessfulAttachmentIsCreatedCorrectly(log!, errorCode: "ATTACHMENT_TOO_LARGE")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_createLogWithAttachment_limitReached() throws {
        givenEmbraceLogUploader()
        givenLogController()
        whenAttachmentLimitIsReached()

        let expectation = XCTestExpectation()
        whenCreatingLogWithAttachment { log in
            self.thenLogWithUnsuccessfulAttachmentIsCreatedCorrectly(log!, errorCode: "OVER_MAX_ATTACHMENTS")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_createLogWithAttachment_serverError() throws {
        givenFailingLogUploader()
        givenLogController()

        let expectation = XCTestExpectation()
        whenCreatingLogWithAttachment { log in
            self.thenLogWithUnsuccessfulAttachmentIsCreatedCorrectly(log!, errorCode: nil)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_createLogWithPreuploadedAttachment() throws {
        givenLogController()

        let expectation = XCTestExpectation()
        whenCreatingLogWithPreUploadedAttachment { log in
            self.thenLogWithPreuploadedAttachmentIsCreatedCorrectly(log!)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func testInfoLog_createLogByDefault_doesntAddStackTraceToAttributes() throws {
        givenLogController()

        let expectation = XCTestExpectation()
        whenCreatingLog(severity: .info) { log in
            self.thenLogHasntGotAnEmbbededStackTraceInTheAttributes(log!)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func testWarningLog_createLogByDefault_addsStackTraceToAttributes() throws {
        givenLogController()

        let expectation = XCTestExpectation()
        whenCreatingLog(severity: .warn) { log in
            self.thenLogHasAnEmbbededStackTraceInTheAttributes(log!)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func testErrorLog_createLogByDefault_addsStackTraceToAttributes() throws {
        givenLogController()

        let expectation = XCTestExpectation()
        whenCreatingLog(severity: .error) { log in
            self.thenLogHasAnEmbbededStackTraceInTheAttributes(log!)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func testWarningLog_createLogByWithNotIncludedStacktrace_doesntAddStackTraceToAttributes() throws {
        givenLogController()

        let expectation = XCTestExpectation()
        whenCreatingLog(severity: .warn, stackTraceBehavior: .notIncluded) { log in
            self.thenLogHasntGotAnEmbbededStackTraceInTheAttributes(log!)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func testErrorLog_createLogByWithNotIncludedStacktrace_doesntAddStackTraceToAttributes() throws {
        givenLogController()

        let expectation = XCTestExpectation()
        whenCreatingLog(severity: .error, stackTraceBehavior: .notIncluded) { log in
            self.thenLogHasntGotAnEmbbededStackTraceInTheAttributes(log!)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func testWarnAndErrorLogs_createLogByWithCustomStacktrace_alwaysAddStackTraceToAttributes() throws {
        givenLogController()

        let customStackTrace = try EmbraceStackTrace(frames: Thread.callStackSymbols)

        let expectation = XCTestExpectation()
        whenCreatingLog(severity: .error, stackTraceBehavior: .custom(customStackTrace)) { log in
            self.thenLogHasAnEmbbededStackTraceInTheAttributes(log!)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func testInfoLogs_createLogByWithCustomStacktrace_wontAddStackTraceToAttributes() throws {
        givenLogController()

        let customStackTrace = try EmbraceStackTrace(frames: Thread.callStackSymbols)

        let expectation = XCTestExpectation()
        whenCreatingLog(severity: .info, stackTraceBehavior: .custom(customStackTrace)) { log in
            self.thenLogHasntGotAnEmbbededStackTraceInTheAttributes(log!)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }
}

extension LogControllerTests {
    fileprivate func randomSeverity(from severities: [EmbraceLogSeverity]) -> EmbraceLogSeverity {
        severities.randomElement()!
    }

    fileprivate func givenLogControllerWithNoStorage() {
        sut = .init(
            storage: nil,
            upload: upload,
            sessionController: sessionController,
            queue: loggingQueue
        )

        sut.sdkStateProvider = sdkStateProvider
    }

    fileprivate func givenLogController() {
        sut = .init(
            storage: storage,
            upload: upload,
            sessionController: sessionController,
            queue: loggingQueue
        )

        sut.sdkStateProvider = sdkStateProvider
    }

    fileprivate func givenEmbraceLogUploader() {
        upload = .init()
        upload.stubbedLogCompletion = .success(())
        upload.stubbedAttachmentCompletion = .success(())
    }

    fileprivate func givenFailingLogUploader() {
        upload = .init()
        upload.stubbedLogCompletion = .failure(RandomError())
        upload.stubbedAttachmentCompletion = .failure(RandomError())
    }

    fileprivate func givenSDKEnabled(_ sdkEnabled: Bool = true) {
        sdkStateProvider.isEnabled = sdkEnabled
    }

    fileprivate func givenSessionControllerWithoutSession() {
        sessionController = .init()
    }

    fileprivate func givenSessionControllerWithSession() {
        sessionController = .init()
        sessionController.currentSession = MockSession(
            id: .random,
            processId: .random,
            state: .foreground,
            traceId: UUID().uuidString,
            spanId: UUID().uuidString,
            startTime: Date()
        )
    }

    fileprivate func givenStorage(withLogs logs: [EmbraceLog] = []) {
        storage = .init()
        storage?.stubbedFetchAllExcludingProcessIdentifier = logs
    }

    fileprivate func whenInvokingSetup() {
        sut.uploadAllPersistedLogs()
    }

    fileprivate func whenInvokingBatchFinished(withLogs logs: [EmbraceLog]) {
        sut.batchFinished(withLogs: logs)
    }

    fileprivate func whenAttachmentLimitIsReached() {
        sut.sessionController?.increaseAttachmentCount()
        sut.sessionController?.increaseAttachmentCount()
        sut.sessionController?.increaseAttachmentCount()
        sut.sessionController?.increaseAttachmentCount()
        sut.sessionController?.increaseAttachmentCount()
    }

    fileprivate func waitForLoggingQueue() {
        let expectation = XCTestExpectation()
        loggingQueue.async {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: .veryLongTimeout)
    }

    fileprivate func whenCreatingLog(
        severity: EmbraceLogSeverity = .info,
        stackTraceBehavior: EmbraceStackTraceBehavior = .default,
        completion: ((EmbraceLog?) -> Void)? = nil
    ) {
        sut.createLog(
            "test",
            severity: severity,
            stackTraceBehavior: stackTraceBehavior,
            completion: completion
        )
        waitForLoggingQueue()
    }

    fileprivate func whenCreatingLogWithAttachment(completion: ((EmbraceLog?) -> Void)? = nil) {
        sut.createLog(
            "test",
            severity: .info,
            attachment: EmbraceLogAttachment(data: TestConstants.data),
            completion: completion
        )
        waitForLoggingQueue()
    }

    fileprivate func whenCreatingLogWithBigAttachment(completion: ((EmbraceLog?) -> Void)? = nil) {
        var str = ""
        for _ in 1...1_048_600 {
            str += "."
        }

        sut.createLog(
            "test",
            severity: .info,
            attachment: EmbraceLogAttachment(data: str.data(using: .utf8)!),
            completion: completion
        )
        waitForLoggingQueue()
    }

    fileprivate func whenCreatingLogWithPreUploadedAttachment(completion: ((EmbraceLog?) -> Void)? = nil) {
        let url = URL(string: "http//embrace.test.com/attachment/123", testName: testName)!
        sut.createLog(
            "test",
            severity: .info,
            attachment: EmbraceLogAttachment(id: UUID().withoutHyphen, url: url),
            completion: completion
        )
        waitForLoggingQueue()
    }

    fileprivate func thenDoesntTryToUploadAnything() {
        XCTAssertFalse(upload.didCallUploadLog)
    }

    fileprivate func thenFetchesAllLogsExcluding(pid: EmbraceIdentifier) throws {
        let unwrappedStorage = try XCTUnwrap(storage)
        XCTAssertTrue(unwrappedStorage.didCallFetchAllExcludingProcessIdentifier)
        XCTAssertEqual(unwrappedStorage.fetchAllExcludingProcessIdentifierReceivedParameter, pid)
    }

    fileprivate func thenLogUploadShouldUpload(times: Int) {
        XCTAssertEqual(upload.didCallUploadLogCount, times)
    }

    fileprivate func thenLogUploaderShouldSendLogs() {
        XCTAssertTrue(upload.didCallUploadLog)
    }

    fileprivate func thenPayloadTypesIsSet(_ types: [String]) {
        guard types.count > 0 else {
            return
        }

        XCTAssertNotNil(upload.logPayloadTypes)
        let payloadTypes = upload.logPayloadTypes!.components(separatedBy: ",")

        XCTAssertEqual(types.count, payloadTypes.count)

        for type in types {
            XCTAssert(payloadTypes.contains(type))
        }
    }

    fileprivate func thenStorageShouldCallRemove(withLogs logs: [EmbraceLog]) throws {
        let unwrappedStorage = try XCTUnwrap(storage)
        wait(timeout: 1.0) {
            let expectedIds = logs.map { $0.id }
            let ids = unwrappedStorage.removeLogsReceivedParameter.map { $0.id }

            return unwrappedStorage.didCallRemoveLogs && expectedIds == ids
        }
    }

    fileprivate func thenStorageShouldntCallRemoveLogs() throws {
        let unwrappedStorage = try XCTUnwrap(storage)
        XCTAssertFalse(unwrappedStorage.didCallRemoveLogs)
    }

    fileprivate func thenFetchesResourcesFromStorage(sessionId: EmbraceIdentifier?) throws {
        let unwrappedStorage = try XCTUnwrap(storage)
        XCTAssertTrue(unwrappedStorage.didCallFetchResourcesForSessionId)
        XCTAssertEqual(unwrappedStorage.fetchResourcesForSessionIdReceivedParameter, sessionId)
    }

    fileprivate func thenFetchesMetadataFromStorage(sessionId: EmbraceIdentifier?) throws {
        let unwrappedStorage = try XCTUnwrap(storage)
        XCTAssertTrue(unwrappedStorage.didCallFetchCustomPropertiesForSessionId)
        XCTAssertEqual(unwrappedStorage.fetchCustomPropertiesForSessionIdReceivedParameter, sessionId)
        XCTAssertTrue(unwrappedStorage.didCallFetchCustomPropertiesForSessionId)
        XCTAssertEqual(unwrappedStorage.fetchPersonaTagsForSessionIdReceivedParameter, sessionId)
    }

    fileprivate func thenFetchesResourcesFromStorage(processId: EmbraceIdentifier) throws {
        let unwrappedStorage = try XCTUnwrap(storage)
        XCTAssertTrue(unwrappedStorage.didCallFetchResourcesForProcessId)
        XCTAssertEqual(unwrappedStorage.fetchResourcesForProcessIdReceivedParameter, processId)
    }

    fileprivate func thenFetchesMetadataFromStorage(processId: EmbraceIdentifier) throws {
        let unwrappedStorage = try XCTUnwrap(storage)
        XCTAssertTrue(unwrappedStorage.didCallFetchPersonaTagsForProcessId)
        XCTAssertEqual(unwrappedStorage.fetchPersonaTagsForProcessIdReceivedParameter, processId)
    }

    fileprivate func thenLogIsCreatedCorrectly(_ log: EmbraceLog) {
        XCTAssertEqual(log.body, "test")
        XCTAssertEqual(log.severity, .info)
        XCTAssertEqual(log.attributes["emb.type"]!.description, "sys.log")
    }

    fileprivate func thenLogHasAnEmbbededStackTraceInTheAttributes(_ log: EmbraceLog) {
        XCTAssertNotNil(log.attributes["emb.stacktrace.ios"])
    }

    fileprivate func thenLogHasntGotAnEmbbededStackTraceInTheAttributes(_ log: EmbraceLog) {
        XCTAssertNil(log.attributes["emb.stacktrace.ios"])
    }

    fileprivate func thenLogWithSuccessfulAttachmentIsCreatedCorrectly(_ log: EmbraceLog) {
        XCTAssertNotNil(log.attributes["emb.attachment_id"])
        XCTAssertNotNil(log.attributes["emb.attachment_size"])
    }

    fileprivate func thenLogWithUnsuccessfulAttachmentIsCreatedCorrectly(_ log: EmbraceLog, errorCode: String?) {
        XCTAssertNotNil(log.attributes["emb.attachment_id"])
        XCTAssertNotNil(log.attributes["emb.attachment_size"])

        if let errorCode {
            XCTAssertEqual(log.attributes["emb.attachment_error_code"], errorCode)
        } else {
            XCTAssertNil(log.attributes["emb.attachment_error_code"])
        }
    }

    fileprivate func thenLogWithPreuploadedAttachmentIsCreatedCorrectly(_ log: EmbraceLog) {
        XCTAssertNotNil(log.attributes["emb.attachment_id"])
        XCTAssertNotNil(log.attributes["emb.attachment_url"])
    }

    fileprivate func randomLogRecord(sessionId: EmbraceIdentifier? = nil, type: String = "log") -> EmbraceLog {
        var attributes: [String: String] = [:]
        if let sessionId = sessionId {
            attributes["session.id"] = sessionId.stringValue
        }

        attributes["emb.type"] = type

        return MockLog(attributes: attributes, sessionId: sessionId)
    }

    fileprivate func logsForMoreThanASingleBatch() -> [EmbraceLog] {
        return (1...20 + 1).map { _ in
            randomLogRecord()
        }
    }
}
