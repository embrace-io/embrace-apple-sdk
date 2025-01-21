//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceCore
import EmbraceStorageInternal
import TestSupport

class DefaultLogBatcherTests: XCTestCase {
    private var sut: DefaultLogBatcher!
    private var repository: SpyLogRepository!
    private var delegate: SpyLogBatcherDelegate!

    func test_addLog_alwaysTriesToCreateLogInRepository() {
        givenDefaultLogBatcher()
        givenRepositoryCreatesLogsSuccessfully()
        whenInvokingAddLogRecord(withLogRecord: randomLogRecord())
        thenLogRepositoryCreateMethodWasInvoked()
    }

    func testOnSuccessfulRepository_whenInvokingAddLog_thenBatchShouldntFinish() {
        givenDefaultLogBatcher()
        givenRepositoryCreatesLogsSuccessfully()
        whenInvokingAddLogRecord(withLogRecord: randomLogRecord())
        thenDelegateShouldntInvokeBatchFinished()
    }

    func testOnSuccessfulRepository_whenInvokingAddLogMoreTimesThanLimit_thenBatchShouldFinish() {
        givenDefaultLogBatcher(limits: .init(maxLogsPerBatch: 1))
        givenRepositoryCreatesLogsSuccessfully()
        whenInvokingAddLogRecord(withLogRecord: randomLogRecord())
        whenInvokingAddLogRecord(withLogRecord: randomLogRecord())
        thenDelegateShouldInvokeBatchFinished()
    }

    func testAutoEndBatchAfterLifespanExpired() {
        givenDefaultLogBatcher(limits: .init(maxBatchAge: 0.1, maxLogsPerBatch: 10))
        givenRepositoryCreatesLogsSuccessfully()
        whenInvokingAddLogRecord(withLogRecord: randomLogRecord())
        thenDelegateShouldInvokeBatchFinishedAfterBatchLifespan(0.5)
    }

    func testAutoEndBatchAfterLifespanExpired_TimerStartsAgainAfterNewLogAdded() {
        givenDefaultLogBatcher(limits: .init(maxBatchAge: 0.1, maxLogsPerBatch: 10))
        givenRepositoryCreatesLogsSuccessfully()
        whenInvokingAddLogRecord(withLogRecord: randomLogRecord())
        thenDelegateShouldInvokeBatchFinishedAfterBatchLifespan(0.5)
        self.delegate.didCallBatchFinished = false
        whenInvokingAddLogRecord(withLogRecord: randomLogRecord())
        thenDelegateShouldInvokeBatchFinishedAfterBatchLifespan(0.5)
    }

    func testAutoEndBatchAfterLifespanExpired_CancelWhenBatchEndedPrematurely() {
        givenDefaultLogBatcher(limits: .init(maxBatchAge: 0.1, maxLogsPerBatch: 3))
        givenRepositoryCreatesLogsSuccessfully()
        whenInvokingAddLogRecord(withLogRecord: randomLogRecord())
        whenInvokingAddLogRecord(withLogRecord: randomLogRecord())
        whenInvokingAddLogRecord(withLogRecord: randomLogRecord())
        thenDelegateShouldInvokeBatchFinished()
        self.delegate.didCallBatchFinished = false
        thenDelegateShouldntInvokeBatchFinishedAfterBatchLifespan(0.2)
    }
}

private extension DefaultLogBatcherTests {
    func givenDefaultLogBatcher(limits: LogBatchLimits = .init()) {
        repository = .init()
        delegate = .init()
        sut = .init(repository: repository, logLimits: limits, delegate: delegate, processorQueue: .main)
    }

    func givenRepositoryCreatesLogsSuccessfully(withLog log: LogRecord? = nil) {
        let logRecord = log ?? randomLogRecord()
        repository.stubbedCreateCompletionResult = .success(logRecord)
    }

    func randomLogRecord() -> LogRecord {
        .init(
            identifier: .init(),
            processIdentifier: .random,
            severity: .info,
            body: UUID().uuidString,
            attributes: [:]
        )
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

    func thenDelegateShouldntInvokeBatchFinishedAfterBatchLifespan(_ lifespan: TimeInterval) {
        wait(timeout: lifespan, until: { !self.delegate.didCallBatchFinished })
    }

    func thenDelegateShouldInvokeBatchFinishedAfterBatchLifespan(_ lifespan: TimeInterval) {
        wait(timeout: lifespan, until: { self.delegate.didCallBatchFinished })
    }
}
