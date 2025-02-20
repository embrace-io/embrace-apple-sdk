//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceCore
import EmbraceStorageInternal
import EmbraceUploadInternal
import EmbraceCommonInternal
import EmbraceConfigInternal
import TestSupport

class LogControllerTests: XCTestCase {
    private var sut: LogController!
    private var storage: SpyStorage?
    private var sessionController: MockSessionController!
    private var upload: SpyEmbraceLogUploader!
    private let sdkStateProvider = MockEmbraceSDKStateProvider()
    private var otelBridge: MockEmbraceOTelBridge!

    override func setUp() {
        givenOTelBridge()
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

    func testHavingThrowingFetchAll_onSetup_shouldRemoveAllLogs() throws {
        givenStorageThatThrowsException()
        givenLogController()
        whenInvokingSetup()
        try thenStorageShouldHaveRemoveAllLogs()
    }

    func testHavingLogs_onSetup_fetchesResourcesFromStorage() throws {
        let sessionId = SessionIdentifier.random
        let log = randomLogRecord(sessionId: sessionId)

        givenStorage(withLogs: [log])
        givenLogController()
        whenInvokingSetup()
        try thenFetchesResourcesFromStorage(sessionId: sessionId)
    }

    func testHavingLogs_onSetup_fetchesMetadataFromStorage() throws {
        let sessionId = SessionIdentifier.random
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
        try thenFetchesResourcesFromStorage(processId: log.processIdentifier)
    }

    func testHavingLogsWithNoSessionId_onSetup_fetchesMetadataFromStorage() throws {
        let log = randomLogRecord()
        givenStorage(withLogs: [log])
        givenLogController()
        whenInvokingSetup()
        try thenFetchesMetadataFromStorage(processId: log.processIdentifier)
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

    func testHavingThrowingStorage_onBatchFinished_wontTryToUploadAnything() {
        givenStorageThatThrowsException()
        givenLogController()
        whenInvokingBatchFinished(withLogs: [randomLogRecord()])
        thenDoesntTryToUploadAnything()
    }

    func test_onBatchFinishedReceivingLogsAmountLargerThanBatch_logUploaderShouldSendASingleBatch() {
        givenLogController()
        let logs = (0...(LogController.maxLogsPerBatch + 5)).map { _ in randomLogRecord() }
        whenInvokingBatchFinished(withLogs: logs)
        thenLogUploadShouldUpload(times: 1)
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
        whenCreatingLog()
        thenLogIsCreatedCorrectly()
    }

    func test_createLogWithAttachment_success() throws {
        givenEmbraceLogUploader()
        givenLogController()
        whenCreatingLogWithAttachment()
        thenLogWithSuccessfulAttachmentIsCreatedCorrectly()
    }

    func test_createLogWithAttachment_tooLarge() throws {
        givenEmbraceLogUploader()
        givenLogController()
        whenCreatingLogWithBigAttachment()
        thenLogWithUnsuccessfulAttachmentIsCreatedCorrectly(errorCode: "ATTACHMENT_TOO_LARGE")
    }

    func test_createLogWithAttachment_limitReached() throws {
        givenEmbraceLogUploader()
        givenLogController()
        whenAttachmentLimitIsReached()
        whenCreatingLogWithAttachment()
        thenLogWithUnsuccessfulAttachmentIsCreatedCorrectly(errorCode: "OVER_MAX_ATTACHMENTS")
    }

    func test_createLogWithAttachment_serverError() throws {
        givenFailingLogUploader()
        givenLogController()
        whenCreatingLogWithAttachment()
        thenLogWithUnsuccessfulAttachmentIsCreatedCorrectly(errorCode: nil)
    }

    func test_createLogWithPreuploadedAttachment() throws {
        givenLogController()
        whenCreatingLogWithPreUploadedAttachment()
        thenLogWithPreuploadedAttachmentIsCreatedCorrectly()
    }

    func testInfoLog_createLogByDefault_doesntAddStackTraceToAttributes() throws {
        givenLogController()
        whenCreatingLog(severity: .info)
        thenLogHasntGotAnEmbbededStackTraceInTheAttributes()
    }

    func testWarningLog_createLogByDefault_addsStackTraceToAttributes() throws {
        givenLogController()
        whenCreatingLog(severity: .warn)
        thenLogHasAnEmbbededStackTraceInTheAttributes()
    }

    func testErrorLog_createLogByDefault_addsStackTraceToAttributes() throws {
        givenLogController()
        whenCreatingLog(severity: .error)
        thenLogHasAnEmbbededStackTraceInTheAttributes()
    }

    func testWarningLog_createLogByWithNotIncludedStacktrace_doesntAddStackTraceToAttributes() throws {
        givenLogController()
        whenCreatingLog(severity: .warn, stackTraceBehavior: .notIncluded)
        thenLogHasntGotAnEmbbededStackTraceInTheAttributes()
    }


    func testErrorLog_createLogByWithNotIncludedStacktrace_doesntAddStackTraceToAttributes() throws {
        givenLogController()
        whenCreatingLog(severity: .error, stackTraceBehavior: .notIncluded)
        thenLogHasntGotAnEmbbededStackTraceInTheAttributes()
    }

    func testAnyLog_createLogByWithCustomStacktrace_alwaysAddStackTraceToAttributes() throws {
        givenLogController()
        let customStackTrace = try EmbraceStackTrace(frames: Thread.callStackSymbols)
        whenCreatingLog(
            severity: randomSeverity(),
            stackTraceBehavior: .custom(customStackTrace)
        )
        thenLogHasAnEmbbededStackTraceInTheAttributes()
    }
}

private extension LogControllerTests {
    func randomSeverity() -> LogSeverity {
        [LogSeverity.error, LogSeverity.warn, LogSeverity.info].randomElement()!
    }

    func givenLogControllerWithNoStorage() {
        sut = .init(
            storage: nil,
            upload: upload,
            controller: sessionController
        )

        sut.sdkStateProvider = sdkStateProvider
        sut.otel = otelBridge
    }

    func givenLogController() {
        sut = .init(
            storage: storage,
            upload: upload,
            controller: sessionController
        )

        sut.sdkStateProvider = sdkStateProvider
        sut.otel = otelBridge
    }

    func givenEmbraceLogUploader() {
        upload = .init()
        upload.stubbedLogCompletion = .success(())
        upload.stubbedAttachmentCompletion = .success(())
    }

    func givenFailingLogUploader() {
        upload = .init()
        upload.stubbedLogCompletion = .failure(RandomError())
        upload.stubbedAttachmentCompletion = .failure(RandomError())
    }

    func givenSDKEnabled(_ sdkEnabled: Bool = true) {
        sdkStateProvider.isEnabled = sdkEnabled
    }

    func givenOTelBridge() {
        otelBridge = MockEmbraceOTelBridge()
    }

    func givenSessionControllerWithoutSession() {
        sessionController = .init()
    }

    func givenSessionControllerWithSession() {
        sessionController = .init()
        sessionController.currentSession = .init(
            id: .random,
            state: .foreground,
            processId: .random,
            traceId: UUID().uuidString,
            spanId: UUID().uuidString,
            startTime: Date()
        )
    }

    func givenStorage(withLogs logs: [LogRecord] = []) {
        storage = .init()
        storage?.stubbedFetchAllExcludingProcessIdentifier = logs
    }

    func givenStorageThatThrowsException() {
        storage = .init(SpyStorage(shouldThrow: true))
    }

    func whenInvokingSetup() {
        sut.uploadAllPersistedLogs()
    }

    func whenInvokingBatchFinished(withLogs logs: [LogRecord]) {
        sut.batchFinished(withLogs: logs)
    }

    func whenAttachmentLimitIsReached() {
        sut.sessionController?.increaseAttachmentCount()
        sut.sessionController?.increaseAttachmentCount()
        sut.sessionController?.increaseAttachmentCount()
        sut.sessionController?.increaseAttachmentCount()
        sut.sessionController?.increaseAttachmentCount()
    }

    func whenCreatingLog(
        severity: LogSeverity = .info,
        stackTraceBehavior: StackTraceBehavior = .default
    ) {
        sut.createLog("test", severity: severity, stackTraceBehavior: stackTraceBehavior)
    }

    func whenCreatingLogWithAttachment() {
        sut.createLog("test", severity: .info, attachment: TestConstants.data)
    }

    func whenCreatingLogWithBigAttachment() {
        var str = ""
        for _ in 1...1048600 {
            str += "."
        }
        sut.createLog("test", severity: .info, attachment: str.data(using: .utf8)!)
    }

    func whenCreatingLogWithPreUploadedAttachment() {
        let url = URL(string: "http//embrace.test.com/attachment/123", testName: testName)!
        sut.createLog("test", severity: .info, attachmentId: UUID().withoutHyphen, attachmentUrl: url)
    }

    func thenDoesntTryToUploadAnything() {
        XCTAssertFalse(upload.didCallUploadLog)
    }

    func thenFetchesAllLogsExcluding(pid: ProcessIdentifier) throws {
        let unwrappedStorage = try XCTUnwrap(storage)
        XCTAssertTrue(unwrappedStorage.didCallFetchAllExcludingProcessIdentifier)
        XCTAssertEqual(unwrappedStorage.fetchAllExcludingProcessIdentifierReceivedParameter, pid)
    }

    func thenStorageShouldHaveRemoveAllLogs() throws {
        let unwrappedStorage = try XCTUnwrap(storage)
        XCTAssertTrue(unwrappedStorage.didCallRemoveAllLogs)
    }

    func thenLogUploadShouldUpload(times: Int) {
        XCTAssertEqual(upload.didCallUploadLogCount, times)
    }

    func thenLogUploaderShouldSendLogs() {
        XCTAssertTrue(upload.didCallUploadLog)
    }

    func thenStorageShouldCallRemove(withLogs logs: [LogRecord]) throws {
        let unwrappedStorage = try XCTUnwrap(storage)
        wait(timeout: 1.0) {
            unwrappedStorage.didCallRemoveLogs && unwrappedStorage.removeLogsReceivedParameter == logs
        }
    }

    func thenStorageShouldntCallRemoveLogs() throws {
        let unwrappedStorage = try XCTUnwrap(storage)
        XCTAssertFalse(unwrappedStorage.didCallRemoveLogs)
    }

    func thenFetchesResourcesFromStorage(sessionId: SessionIdentifier?) throws {
        let unwrappedStorage = try XCTUnwrap(storage)
        XCTAssertTrue(unwrappedStorage.didCallFetchResourcesForSessionId)
        XCTAssertEqual(unwrappedStorage.fetchResourcesForSessionIdReceivedParameter, sessionId)
    }

    func thenFetchesMetadataFromStorage(sessionId: SessionIdentifier?) throws {
        let unwrappedStorage = try XCTUnwrap(storage)
        XCTAssertTrue(unwrappedStorage.didCallFetchCustomPropertiesForSessionId)
        XCTAssertEqual(unwrappedStorage.fetchCustomPropertiesForSessionIdReceivedParameter, sessionId)
        XCTAssertTrue(unwrappedStorage.didCallFetchCustomPropertiesForSessionId)
        XCTAssertEqual(unwrappedStorage.fetchPersonaTagsForSessionIdReceivedParameter, sessionId)
    }

    func thenFetchesResourcesFromStorage(processId: ProcessIdentifier) throws {
        let unwrappedStorage = try XCTUnwrap(storage)
        XCTAssertTrue(unwrappedStorage.didCallFetchResourcesForProcessId)
        XCTAssertEqual(unwrappedStorage.fetchResourcesForProcessIdReceivedParameter, processId)
    }

    func thenFetchesMetadataFromStorage(processId: ProcessIdentifier) throws {
        let unwrappedStorage = try XCTUnwrap(storage)
        XCTAssertTrue(unwrappedStorage.didCallFetchPersonaTagsForProcessId)
        XCTAssertEqual(unwrappedStorage.fetchPersonaTagsForProcessIdReceivedParameter, processId)
    }

    func thenLogIsCreatedCorrectly() {
        let log = otelBridge.otel.logs.first
        XCTAssertNotNil(log)
        XCTAssertEqual(log!.body!.description, "test")
        XCTAssertEqual(log!.severity, .info)
        XCTAssertEqual(log!.attributes["emb.type"]!.description, "sys.log")
    }

    func thenLogHasAnEmbbededStackTraceInTheAttributes() {
        wait {
            let log = self.otelBridge.otel.logs.first

            return log!.attributes["emb.stacktrace.ios"] != nil
        }
    }

    func thenLogHasntGotAnEmbbededStackTraceInTheAttributes() {
        wait {
            let log = self.otelBridge.otel.logs.first

            return log!.attributes["emb.stacktrace.ios"] == nil
        }
    }

    func thenLogWithSuccessfulAttachmentIsCreatedCorrectly() {
        wait {
            let log = self.otelBridge.otel.logs.first

            let attachmentIdFound = log!.attributes["emb.attachment_id"] != nil
            let attachmentSizeFound = log!.attributes["emb.attachment_size"] != nil

            return attachmentIdFound && attachmentSizeFound
        }
    }

    func thenLogWithUnsuccessfulAttachmentIsCreatedCorrectly(errorCode: String?) {
        wait {
            let log = self.otelBridge.otel.logs.first

            let attachmentIdFound = log!.attributes["emb.attachment_id"] != nil
            let attachmentSizeFound = log!.attributes["emb.attachment_size"] != nil
            let attachmentErrorFound = errorCode == nil || log!.attributes["emb.attachment_error_code"]!.description == errorCode

            return attachmentIdFound && attachmentSizeFound && attachmentErrorFound
        }
    }

    func thenLogWithPreuploadedAttachmentIsCreatedCorrectly() {
        wait {
            let log = self.otelBridge.otel.logs.first

            let attachmentIdFound = log!.attributes["emb.attachment_id"] != nil
            let attachmentUrlFound = log!.attributes["emb.attachment_url"] != nil

            return attachmentIdFound && attachmentUrlFound
        }
    }

    func randomLogRecord(sessionId: SessionIdentifier? = nil) -> LogRecord {

        var attributes: [String: PersistableValue] = [:]
        if let sessionId = sessionId {
            attributes["session.id"] = PersistableValue(sessionId.toString)
        }

        return LogRecord(
            identifier: .random,
            processIdentifier: .random,
            severity: .info,
            body: UUID().uuidString,
            attributes: attributes
        )
    }

    func logsForMoreThanASingleBatch() -> [LogRecord] {
        return (1...LogController.maxLogsPerBatch + 1).map { _ in
            randomLogRecord()
        }
    }
}

extension LogRecord: Equatable {
    public static func == (lhs: LogRecord, rhs: LogRecord) -> Bool {
        lhs.identifier == rhs.identifier
    }
}
