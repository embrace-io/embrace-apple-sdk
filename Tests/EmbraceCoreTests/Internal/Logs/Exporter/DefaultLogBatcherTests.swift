//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceStorageInternal
import OpenTelemetrySdk
import TestSupport
import XCTest

@testable import EmbraceCore

class DefaultLogBatcherTests: XCTestCase {
    private var sut: DefaultLogBatcher!
    private var repository: SpyLogRepository!
    private var delegate: SpyLogBatcherDelegate!

    func test_addLog_alwaysTriesToCreateLogInRepository() {
        givenDefaultLogBatcher()
        whenInvokingAddLogRecord(withLogRecord: randomLogRecord())
        thenLogRepositoryCreateMethodWasInvoked()
    }

    func testOnSuccessfulRepository_whenInvokingAddLog_thenBatchShouldntFinish() {
        givenDefaultLogBatcher()
        whenInvokingAddLogRecord(withLogRecord: randomLogRecord())
        thenDelegateShouldntInvokeBatchFinished()
    }

    func testOnSuccessfulRepository_whenInvokingAddLogMoreTimesThanLimit_thenBatchShouldFinish() {
        givenDefaultLogBatcher(limits: .init(maxLogsPerBatch: 1))
        whenInvokingAddLogRecord(withLogRecord: randomLogRecord())
        whenInvokingAddLogRecord(withLogRecord: randomLogRecord())
        thenDelegateShouldInvokeBatchFinished()
    }

    func testAutoEndBatchAfterLifespanExpired() {
        givenDefaultLogBatcher(limits: .init(maxBatchAge: 0.1, maxLogsPerBatch: 10))
        whenInvokingAddLogRecord(withLogRecord: randomLogRecord())
        thenDelegateShouldInvokeBatchFinishedAfterBatchLifespan(0.5)
    }

    func testAutoEndBatchAfterLifespanExpired_TimerStartsAgainAfterNewLogAdded() {
        givenDefaultLogBatcher(limits: .init(maxBatchAge: 0.1, maxLogsPerBatch: 10))
        whenInvokingAddLogRecord(withLogRecord: randomLogRecord())
        thenDelegateShouldInvokeBatchFinishedAfterBatchLifespan(0.5)
        self.delegate.didCallBatchFinished = false
        whenInvokingAddLogRecord(withLogRecord: randomLogRecord())
        thenDelegateShouldInvokeBatchFinishedAfterBatchLifespan(0.5)
    }

    func testAutoEndBatchAfterLifespanExpired_CancelWhenBatchEndedPrematurely() {
        givenDefaultLogBatcher(limits: .init(maxBatchAge: 0.1, maxLogsPerBatch: 3))
        whenInvokingAddLogRecord(withLogRecord: randomLogRecord())
        whenInvokingAddLogRecord(withLogRecord: randomLogRecord())
        whenInvokingAddLogRecord(withLogRecord: randomLogRecord())
        thenDelegateShouldInvokeBatchFinished()
        self.delegate.didCallBatchFinished = false
        thenDelegateShouldntInvokeBatchFinishedAfterBatchLifespan(0.5)
    }
}

extension DefaultLogBatcherTests {
    fileprivate func givenDefaultLogBatcher(limits: LogBatchLimits = .init()) {
        repository = .init()
        delegate = .init()
        sut = .init(repository: repository, logLimits: limits, delegate: delegate, processorQueue: .main)
    }

    fileprivate func randomLogRecord() -> ReadableLogRecord {
        return ReadableLogRecord(
            resource: Resource(),
            instrumentationScopeInfo: InstrumentationScopeInfo(),
            timestamp: Date(),
            attributes: [:]
        )
    }

    fileprivate func whenInvokingAddLogRecord(withLogRecord logRecord: ReadableLogRecord) {
        sut.addLogRecord(logRecord: logRecord)
    }

    fileprivate func thenLogRepositoryCreateMethodWasInvoked() {
        wait(
            timeout: 1.0,
            until: {
                self.repository.didCallCreate
            })
    }

    fileprivate func thenDelegateShouldntInvokeBatchFinished() {
        wait(timeout: 1.0, until: { !self.delegate.didCallBatchFinished })
    }

    fileprivate func thenDelegateShouldInvokeBatchFinished() {
        wait(timeout: 1.0, until: { self.delegate.didCallBatchFinished })
    }

    fileprivate func thenDelegateShouldntInvokeBatchFinishedAfterBatchLifespan(_ lifespan: TimeInterval) {
        wait(timeout: lifespan, until: { !self.delegate.didCallBatchFinished })
    }

    fileprivate func thenDelegateShouldInvokeBatchFinishedAfterBatchLifespan(_ lifespan: TimeInterval) {
        wait(timeout: lifespan, until: { self.delegate.didCallBatchFinished })
    }
}
