//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceCore
import EmbraceStorage
import TestSupport

class DefaultLogBatcherTests: XCTestCase {
    private var sut: DefaultLogBatcher!
    private var repository: SpyLogRepository!
    private var delegate: SpyLogBatcherDelegate!

    func test_addLog_alwaysTriesToCreateLogInRepository() {
        givenDefaultLogBatcher()
        givenRepositoryCreatesLogsSucessfully()
        whenInvokingAddLogRecord(withLogRecord: randomLogRecord())
        thenLogRepositoryCreateMethodWasInvoked()
    }

    func testOnSuccessfulRepository_whenInvokingAddLog_thenBatchShouldntFinish() {
        givenDefaultLogBatcher()
        givenRepositoryCreatesLogsSucessfully()
        whenInvokingAddLogRecord(withLogRecord: randomLogRecord())
        thenDelegateShouldntInvokeBatchFinished()
    }

    func testOnSuccessfulRepository_whenInvokingAddLogMoreTimesThanLimit_thenBatchShouldFinish() {
        givenDefaultLogBatcher(limits: .init(maxLogsPerBatch: 1))
        givenRepositoryCreatesLogsSucessfully()
        whenInvokingAddLogRecord(withLogRecord: randomLogRecord())
        whenInvokingAddLogRecord(withLogRecord: randomLogRecord())
        thenDelegateShouldInvokeBatchFinished()
    }
}

private extension DefaultLogBatcherTests {
    func givenDefaultLogBatcher(limits: LogBatchLimits = .init()) {
        repository = .init()
        delegate = .init()
        sut = .init(repository: repository, logLimits: limits, delegate: delegate, processorQueue: .main)
    }

    func givenRepositoryCreatesLogsSucessfully(withLog log: LogRecord? = nil) {
        let logRecord = log ?? randomLogRecord()
        repository.stubbedCreateCompletionResult = .success(logRecord)
    }

    func randomLogRecord() -> LogRecord {
        .init(id: .init(), severity: .info, body: UUID().uuidString, attributes: [:])
    }

    func whenInvokingAddLogRecord(withLogRecord logRecord: LogRecord) {
        sut.addLogRecord(logRecord: logRecord)
    }

    func thenLogRepositoryCreateMethodWasInvoked() {
        wait(timeout: 1.0, until: {
            self.repository.didCallCreate
        })
    }

    func thenDelegateShouldntInvokeBatchFinished() {
        wait(timeout: 1.0, until: { !self.delegate.didCallBatchFinished })
    }

    func thenDelegateShouldInvokeBatchFinished() {
        wait(timeout: 1.0, until: { self.delegate.didCallBatchFinished })
    }
}
