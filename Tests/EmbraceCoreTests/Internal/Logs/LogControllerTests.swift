//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceConfigInternal
import EmbraceStorageInternal
import EmbraceUploadInternal
import OpenTelemetryApi
import TestSupport
import XCTest

@testable import EmbraceCore

class LogControllerTests: XCTestCase {
    private var sut: LogController!
    private var storage: SpyStorage?
    private var sessionController: MockSessionController!
    private var upload: SpyEmbraceLogUploader!
    private let sdkStateProvider = MockEmbraceSDKStateProvider()
    private var otelBridge: MockEmbraceOTelBridge!
    private let loggingQueue = DispatchQueue(label: "loggingQueue")

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
        try thenFetchesResourcesFromStorage(processId: log.processId!)
    }

    func testHavingLogsWithNoSessionId_onSetup_fetchesMetadataFromStorage() throws {
        let log = randomLogRecord()
        givenStorage(withLogs: [log])
        givenLogController()
        whenInvokingSetup()
        try thenFetchesMetadataFromStorage(processId: log.processId!)
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
        let logs = (0...(LogController.maxLogsPerBatch + 5)).map { _ in randomLogRecord() }
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

    func testWarnAndErrorLogs_createLogByWithCustomStacktrace_alwaysAddStackTraceToAttributes() throws {
        givenLogController()
        let customStackTrace = try EmbraceStackTrace(frames: Thread.callStackSymbols)
        whenCreatingLog(
            severity: [.warn, .error].randomElement()!,
            stackTraceBehavior: .custom(customStackTrace)
        )
        thenLogHasAnEmbbededStackTraceInTheAttributes()
    }

    func testInfoLogs_createLogByWithCustomStacktrace_wontAddStackTraceToAttributes() throws {
        givenLogController()
        let customStackTrace = try EmbraceStackTrace(frames: Thread.callStackSymbols)
        whenCreatingLog(
            severity: .info,
            stackTraceBehavior: .custom(customStackTrace)
        )
        thenLogHasntGotAnEmbbededStackTraceInTheAttributes()
    }
}

extension LogControllerTests {
    fileprivate func randomSeverity(from severities: [LogSeverity]) -> LogSeverity {
        severities.randomElement()!
    }

    fileprivate func givenLogControllerWithNoStorage() {
        sut = .init(
            storage: nil,
            upload: upload,
            controller: sessionController
        )

        sut.sdkStateProvider = sdkStateProvider
        sut.otel = otelBridge
    }

    fileprivate func givenLogController() {
        sut = .init(
            storage: storage,
            upload: upload,
            controller: sessionController
        )

        sut.sdkStateProvider = sdkStateProvider
        sut.otel = otelBridge
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

    fileprivate func givenOTelBridge() {
        otelBridge = MockEmbraceOTelBridge()
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
        severity: LogSeverity = .info,
        stackTraceBehavior: StackTraceBehavior = .default
    ) {
        sut.createLog("test", severity: severity, stackTraceBehavior: stackTraceBehavior, queue: loggingQueue)
        waitForLoggingQueue()
    }

    fileprivate func whenCreatingLogWithAttachment() {
        sut.createLog("test", severity: .info, attachment: TestConstants.data, queue: loggingQueue)
        waitForLoggingQueue()
    }

    fileprivate func whenCreatingLogWithBigAttachment() {
        var str = ""
        for _ in 1...1_048_600 {
            str += "."
        }
        sut.createLog("test", severity: .info, attachment: str.data(using: .utf8)!, queue: loggingQueue)
        waitForLoggingQueue()
    }

    fileprivate func whenCreatingLogWithPreUploadedAttachment() {
        let url = URL(string: "http//embrace.test.com/attachment/123", testName: testName)!
        sut.createLog(
            "test", severity: .info, attachmentId: UUID().withoutHyphen, attachmentUrl: url, queue: loggingQueue)
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

    fileprivate func thenStorageShouldHaveRemoveAllLogs() throws {
        let unwrappedStorage = try XCTUnwrap(storage)
        XCTAssertTrue(unwrappedStorage.didCallRemoveAllLogs)
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
            let expectedIds = logs.map { $0.idRaw }
            let ids = unwrappedStorage.removeLogsReceivedParameter.map { $0.idRaw }

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

    fileprivate func thenLogIsCreatedCorrectly() {
        let log = otelBridge.otel.logs.first
        XCTAssertNotNil(log)
        XCTAssertEqual(log!.body!.description, "test")
        XCTAssertEqual(log!.severity, .info)
        XCTAssertEqual(log!.attributes["emb.type"]!.description, "sys.log")
    }

    fileprivate func thenLogHasAnEmbbededStackTraceInTheAttributes() {
        wait {
            let log = self.otelBridge.otel.logs.first

            return log!.attributes["emb.stacktrace.ios"] != nil
        }
    }

    fileprivate func thenLogHasntGotAnEmbbededStackTraceInTheAttributes() {
        wait {
            let log = self.otelBridge.otel.logs.first

            return log!.attributes["emb.stacktrace.ios"] == nil
        }
    }

    fileprivate func thenLogWithSuccessfulAttachmentIsCreatedCorrectly() {
        wait {
            let log = self.otelBridge.otel.logs.first

            let attachmentIdFound = log!.attributes["emb.attachment_id"] != nil
            let attachmentSizeFound = log!.attributes["emb.attachment_size"] != nil

            return attachmentIdFound && attachmentSizeFound
        }
    }

    fileprivate func thenLogWithUnsuccessfulAttachmentIsCreatedCorrectly(errorCode: String?) {
        wait {
            let log = self.otelBridge.otel.logs.first

            let attachmentIdFound = log!.attributes["emb.attachment_id"] != nil
            let attachmentSizeFound = log!.attributes["emb.attachment_size"] != nil
            let attachmentErrorFound =
                errorCode == nil || log!.attributes["emb.attachment_error_code"]!.description == errorCode

            return attachmentIdFound && attachmentSizeFound && attachmentErrorFound
        }
    }

    fileprivate func thenLogWithPreuploadedAttachmentIsCreatedCorrectly() {
        wait {
            let log = self.otelBridge.otel.logs.first

            let attachmentIdFound = log!.attributes["emb.attachment_id"] != nil
            let attachmentUrlFound = log!.attributes["emb.attachment_url"] != nil

            return attachmentIdFound && attachmentUrlFound
        }
    }

    fileprivate func randomLogRecord(
        sessionId: EmbraceIdentifier? = nil,
        type: String = "test"
    ) -> EmbraceLog {

        var attributes: [String: AttributeValue] = [:]
        if let sessionId = sessionId {
            attributes["session.id"] = AttributeValue(sessionId.stringValue)
        }

        attributes["emb.type"] = AttributeValue(type)

        return MockLog(
            id: .random,
            processId: .random,
            severity: .info,
            body: UUID().uuidString,
            attributes: attributes
        )
    }

    fileprivate func logsForMoreThanASingleBatch() -> [EmbraceLog] {
        return (1...LogController.maxLogsPerBatch + 1).map { _ in
            randomLogRecord()
        }
    }
}
