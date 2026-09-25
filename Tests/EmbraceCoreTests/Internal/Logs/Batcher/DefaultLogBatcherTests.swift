//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceSemantics
import EmbraceStorageInternal
import TestSupport
import XCTest

@testable import EmbraceCore

class DefaultLogBatcherTests: XCTestCase {
    private let processorQueue = DispatchQueue(label: "io.embrace.tests.logBatcher")
    private var sut: DefaultLogBatcher!
    private var delegate: SpyLogBatcherDelegate!

    // Appended on `processorQueue`; read after `drainProcessorQueue()`.
    private var scheduledDeadlines: [(delay: TimeInterval, item: DispatchWorkItem)] = []

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
        thenDeadlinesShouldBeScheduled(withDelays: [0.1])
        thenDelegateShouldntInvokeBatchFinished()

        whenLatestDeadlineFires()
        thenDelegateShouldInvokeBatchFinished()
    }

    func testAutoEndBatchAfterLifespanExpired_TimerStartsAgainAfterNewLogAdded() {
        givenDefaultLogBatcher(limits: .init(maxBatchAge: 0.1, maxLogsPerBatch: 10))
        whenInvokingAddLog(withLog: MockLog())
        whenLatestDeadlineFires()
        thenDelegateShouldInvokeBatchFinished()

        delegate.didCallBatchFinished = false
        whenInvokingAddLog(withLog: MockLog())
        thenDeadlinesShouldBeScheduled(withDelays: [0.1, 0.1])
        thenDelegateShouldntInvokeBatchFinished()

        whenLatestDeadlineFires()
        thenDelegateShouldInvokeBatchFinished()
    }

    func testAutoEndBatchAfterLifespanExpired_CancelWhenBatchEndedPrematurely() {
        givenDefaultLogBatcher(limits: .init(maxBatchAge: 0.1, maxLogsPerBatch: 3))
        whenInvokingAddLog(withLog: MockLog())
        whenInvokingAddLog(withLog: MockLog())
        whenInvokingAddLog(withLog: MockLog())
        thenDelegateShouldInvokeBatchFinished()

        delegate.didCallBatchFinished = false
        whenLatestDeadlineFires()
        thenDelegateShouldntInvokeBatchFinished()
    }
}

extension DefaultLogBatcherTests {
    fileprivate func givenDefaultLogBatcher(limits: LogBatchLimits = .init()) {
        delegate = .init()
        sut = .init(logBatchLimits: limits, processorQueue: processorQueue) { delay, item in
            self.scheduledDeadlines.append((delay, item))
        }
        sut.delegate = delegate
    }

    fileprivate func whenInvokingAddLog(withLog log: EmbraceLog) {
        sut.addLog(log)
    }

    /// Runs the deadline on the processor queue the way `asyncAfter` would, so a canceled deadline
    /// doesn't run.
    fileprivate func whenLatestDeadlineFires() {
        drainProcessorQueue()
        guard let deadline = scheduledDeadlines.last else {
            XCTFail("No batch deadline was scheduled")
            return
        }
        processorQueue.async(execute: deadline.item)
    }

    fileprivate func thenDeadlinesShouldBeScheduled(withDelays delays: [TimeInterval]) {
        drainProcessorQueue()
        XCTAssertEqual(scheduledDeadlines.map(\.delay), delays)
    }

    fileprivate func thenDelegateShouldntInvokeBatchFinished() {
        drainProcessorQueue()
        XCTAssertFalse(delegate.didCallBatchFinished)
    }

    fileprivate func thenDelegateShouldInvokeBatchFinished() {
        drainProcessorQueue()
        XCTAssertTrue(delegate.didCallBatchFinished)
    }

    /// Blocks until every block already queued on the batcher's processor queue has run.
    fileprivate func drainProcessorQueue() {
        processorQueue.sync {}
    }
}
