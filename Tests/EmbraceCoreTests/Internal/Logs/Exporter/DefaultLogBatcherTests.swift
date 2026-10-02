//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceStorageInternal
import OpenTelemetrySdk
import TestSupport
import XCTest

@testable import EmbraceCore

class DefaultLogBatcherTests: XCTestCase {
    private let processorQueue = DispatchQueue(label: "io.embrace.tests.logBatcher")
    private var sut: DefaultLogBatcher!
    private var repository: SpyLogRepository!
    private var delegate: SpyLogBatcherDelegate!

    // Appended on `processorQueue`; read after `drainProcessorQueue()`.
    private var scheduledDeadlines: [(delay: TimeInterval, item: DispatchWorkItem)] = []

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
        thenDeadlinesShouldBeScheduled(withDelays: [0.1])
        thenDelegateShouldntInvokeBatchFinished()

        whenLatestDeadlineFires()
        thenDelegateShouldInvokeBatchFinished()
    }

    func testAutoEndBatchAfterLifespanExpired_TimerStartsAgainAfterNewLogAdded() {
        givenDefaultLogBatcher(limits: .init(maxBatchAge: 0.1, maxLogsPerBatch: 10))
        whenInvokingAddLogRecord(withLogRecord: randomLogRecord())
        whenLatestDeadlineFires()
        thenDelegateShouldInvokeBatchFinished()

        delegate.didCallBatchFinished = false
        whenInvokingAddLogRecord(withLogRecord: randomLogRecord())
        thenDeadlinesShouldBeScheduled(withDelays: [0.1, 0.1])
        thenDelegateShouldntInvokeBatchFinished()

        whenLatestDeadlineFires()
        thenDelegateShouldInvokeBatchFinished()
    }

    func testAutoEndBatchAfterLifespanExpired_CancelWhenBatchEndedPrematurely() {
        givenDefaultLogBatcher(limits: .init(maxBatchAge: 0.1, maxLogsPerBatch: 3))
        whenInvokingAddLogRecord(withLogRecord: randomLogRecord())
        whenInvokingAddLogRecord(withLogRecord: randomLogRecord())
        whenInvokingAddLogRecord(withLogRecord: randomLogRecord())
        thenDelegateShouldInvokeBatchFinished()

        delegate.didCallBatchFinished = false
        whenLatestDeadlineFires()
        thenDelegateShouldntInvokeBatchFinished()
    }
}

extension DefaultLogBatcherTests {
    fileprivate func givenDefaultLogBatcher(limits: LogBatchLimits = .init()) {
        repository = .init()
        delegate = .init()
        sut = .init(
            repository: repository,
            logLimits: limits,
            delegate: delegate,
            processorQueue: processorQueue
        ) { delay, item in
            self.scheduledDeadlines.append((delay, item))
        }
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

    fileprivate func thenLogRepositoryCreateMethodWasInvoked() {
        drainProcessorQueue()
        XCTAssertTrue(repository.didCallCreate)
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

    /// Blocks until every block queued on the batcher's processor queue has run, including the ones
    /// those blocks queue.
    ///
    /// `addLogRecord` creates the log on `processorQueue` and then queues `addLogToBatch` on it
    /// again, so the second block can land behind a single `sync {}`. Draining twice covers that hop.
    fileprivate func drainProcessorQueue() {
        processorQueue.sync {}
        processorQueue.sync {}
    }
}
