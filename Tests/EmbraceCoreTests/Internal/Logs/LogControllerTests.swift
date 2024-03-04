//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceCore
import EmbraceStorage
import EmbraceUpload
import EmbraceCommon

class LogControllerTests: XCTestCase {
    private var sut: LogController!
    private var storage: SpyStorage?
    private var sessionController: SpySessionController!
    private var upload: SpyEmbraceLogUploader!

    override func setUp() {
        givenEmbraceLogUploader()
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
        givenStorage(withLogs: [randomLogRecord()])
        givenLogController()
        whenInvokingSetup()
        try thenFetchesResourcesForCurrentSessionIdFromStorage()
    }

    func testHavingLogs_onSetup_fetchesMetadataFromStorage() throws {
        givenStorage(withLogs: [randomLogRecord()])
        givenLogController()
        whenInvokingSetup()
        try thenFetchesMetadataForCurrentSessionIdFromStorage()
    }

    func testHavingLogsButNoSession_onSetup_wontTryToUploadAnything() {
        givenSessionControllerWithoutSession()
        givenStorage(withLogs: [randomLogRecord()])
        givenLogController()
        whenInvokingSetup()
        thenDoesntTryToUploadAnything()
    }

    func testHavingLogsForLessThanABatch_onSetup_logUploaderShouldSendASingleBatch() {
        givenStorage(withLogs: [randomLogRecord(), randomLogRecord()])
        givenLogController()
        whenInvokingSetup()
        thenLogUploadShouldUpload(times: 1)
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

    func testHavingLogs_onBatchFinished_fetchesResourcesFromStorage() throws {
        givenLogController()
        whenInvokingBatchFinished(withLogs: [randomLogRecord()])
        try thenFetchesResourcesForCurrentSessionIdFromStorage()
    }

    func testHavingLogs_onBatchFinished_fetchesMetadataFromStorage() throws {
        givenLogController()
        whenInvokingBatchFinished(withLogs: [randomLogRecord()])
        try thenFetchesMetadataForCurrentSessionIdFromStorage()
    }

    func testHavingLogs_onBatchFinished_logUploaderShouldSendASingleBatch() throws {
        givenLogController()
        whenInvokingBatchFinished(withLogs: [randomLogRecord()])
        try thenFetchesMetadataForCurrentSessionIdFromStorage()
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
}

private extension LogControllerTests {
    func givenLogControllerWithNoStorage() {
        sut = .init(storage: nil, upload: upload, controller: sessionController)
    }

    func givenLogController() {
        sut = .init(storage: storage, upload: upload, controller: sessionController)
    }

    func givenEmbraceLogUploader() {
        upload = .init()
        upload.stubbedCompletion = .success(())
    }

    func givenFailingLogUploader() {
        upload = .init()
        upload.stubbedCompletion = .failure(RandomError())
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
        sut.setup()
    }

    func whenInvokingBatchFinished(withLogs logs: [LogRecord]) {
        sut.batchFinished(withLogs: logs)
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
        XCTAssertTrue(upload.didCallUploadLog)
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

    func thenFetchesResourcesForCurrentSessionIdFromStorage() throws {
        let unwrappedStorage = try XCTUnwrap(storage)
        let currentSessionId = sessionController.currentSession?.id
        XCTAssertTrue(unwrappedStorage.didCallFetchResourcesForSessionId)
        XCTAssertEqual(unwrappedStorage.fetchResourcesForSessionIdReceivedParameter, currentSessionId)
    }

    func thenFetchesMetadataForCurrentSessionIdFromStorage() throws {
        let unwrappedStorage = try XCTUnwrap(storage)
        let currentSessionId = sessionController.currentSession?.id
        XCTAssertTrue(unwrappedStorage.didCallFetchCustomPropertiesForSessionId)
        XCTAssertEqual(unwrappedStorage.fetchCustomPropertiesForSessionIdReceivedParameter, currentSessionId)
    }

    func randomLogRecord() -> LogRecord {
        .init(
            identifier: .random,
            processIdentifier: .random,
            severity: .info,
            body: UUID().uuidString,
            attributes: .empty()
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
