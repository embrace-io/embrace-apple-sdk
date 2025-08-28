//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceStorageInternal
import TestSupport
import XCTest
import EmbraceSemantics
@testable import EmbraceCore

class DefaultLogBatcherTests: XCTestCase {
    private var sut: DefaultLogBatcher!
    private var delegate: SpyLogBatcherDelegate!

    func testOnSuccessfulRepository_whenInvokingAddLog_thenBatchShouldntFinish() {
        givenDefaultLogBatcher()
        whenInvokingAddLog(withLog: MockLog())
        thenDelegateShouldntInvokeBatchFinished()
    }

    func testOnSuccessfulRepository_whenInvokingAddLogMoreTimesThanLimit_thenBatchShouldFinish() {
        givenDefaultLogBatcher(limits: .init(maxLogsPerBatch: 1))
        whenInvokingAddLog(withLog: MockLog())
        whenInvokingAddLog(withLog: MockLog())
        thenDelegateShouldInvokeBatchFinished()
    }

    func testAutoEndBatchAfterLifespanExpired() {
        givenDefaultLogBatcher(limits: .init(maxBatchAge: 0.1, maxLogsPerBatch: 10))
        whenInvokingAddLog(withLog: MockLog())
        thenDelegateShouldInvokeBatchFinishedAfterBatchLifespan(0.5)
    }

    func testAutoEndBatchAfterLifespanExpired_TimerStartsAgainAfterNewLogAdded() {
        givenDefaultLogBatcher(limits: .init(maxBatchAge: 0.1, maxLogsPerBatch: 10))
        whenInvokingAddLog(withLog: MockLog())
        thenDelegateShouldInvokeBatchFinishedAfterBatchLifespan(0.5)
        self.delegate.didCallBatchFinished = false
        whenInvokingAddLog(withLog: MockLog())
        thenDelegateShouldInvokeBatchFinishedAfterBatchLifespan(0.5)
    }

    func testAutoEndBatchAfterLifespanExpired_CancelWhenBatchEndedPrematurely() {
        givenDefaultLogBatcher(limits: .init(maxBatchAge: 0.1, maxLogsPerBatch: 3))
        whenInvokingAddLog(withLog: MockLog())
        whenInvokingAddLog(withLog: MockLog())
        whenInvokingAddLog(withLog: MockLog())
        thenDelegateShouldInvokeBatchFinished()
        self.delegate.didCallBatchFinished = false
        thenDelegateShouldntInvokeBatchFinishedAfterBatchLifespan(0.5)
    }
}

extension DefaultLogBatcherTests {
    fileprivate func givenDefaultLogBatcher(limits: LogBatchLimits = .init()) {
        delegate = .init()
        sut = .init(logBatchLimits: limits, processorQueue: .main)
        sut.delegate = delegate
    }

    fileprivate func whenInvokingAddLog(withLog log: EmbraceLog) {
        sut.addLog(log)
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
