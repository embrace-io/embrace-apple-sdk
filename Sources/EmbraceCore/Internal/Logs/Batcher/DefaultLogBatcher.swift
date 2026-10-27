//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
    import EmbraceStorageInternal
    import EmbraceCommonInternal
    import EmbraceConfiguration
#endif

protocol LogBatcherDelegate: AnyObject {
    /// Called on the batcher's processing queue when a batch is closed.
    /// - Parameters:
    ///   - logs: the logs contained in the batch.
    ///   - session: the session the batch belongs to, when it's known at the time the batch is closed
    ///     (e.g. a batch force-ended because a session part is ending). `nil` when the batch closed on its own
    ///     (deadline or size limit), in which case the delegate should resolve the session itself.
    func batchFinished(withLogs logs: [EmbraceLog], session: EmbraceSession?)
}

protocol LogBatcher: AnyObject {
    func addLog(_ log: EmbraceLog)
    func renewBatch(withLogs logRecords: [EmbraceLog])
    func forceEndCurrentBatch(endingSession: EmbraceSession?)

    var logBatchLimits: LogBatchLimits { get }
    var delegate: LogBatcherDelegate? { get set }

    /// Test-only: the in-flight batch, read synchronized on the batcher's processing queue.
    func currentBatch() -> LogsBatch?
}

class DefaultLogBatcher: LogBatcher {
    let logBatchLimits: LogBatchLimits
    private let processorQueue: DispatchQueue

    weak var delegate: LogBatcherDelegate?

    private var batchDeadlineWorkItem: DispatchWorkItem?

    // Mutated and read exclusively on `processorQueue` by the SDK. Tests observe it via
    // `currentBatch()`, which hops onto that same queue so the read can't race these writes.
    private var batch: LogsBatch?

    /// Schedules the work item that ends the current batch once it reaches its maximum age.
    /// It's called on `processorQueue`, and the item must run there too.
    typealias DeadlineScheduler = (_ delay: TimeInterval, _ item: DispatchWorkItem) -> Void
    private let scheduleDeadline: DeadlineScheduler

    /// - Parameters:
    ///   - scheduleDeadline: Schedules the batch deadline. It defaults to `asyncAfter` on
    ///     `processorQueue`; tests pass their own so they can fire the deadline themselves.
    init(
        logBatchLimits: LogBatchLimits = LogBatchLimits(),
        processorQueue: DispatchQueue = .init(label: "io.embrace.logBatcher"),
        scheduleDeadline: DeadlineScheduler? = nil
    ) {
        self.logBatchLimits = logBatchLimits
        self.processorQueue = processorQueue
        self.scheduleDeadline =
            scheduleDeadline ?? { delay, item in
                let milliseconds = DispatchTimeInterval.milliseconds(Int(delay * 1000))
                processorQueue.asyncAfter(deadline: .now() + milliseconds, execute: item)
            }
    }

    /// Test-only synchronized read of `batch`: hops onto `processorQueue` (which owns every `batch`
    /// mutation) so test-thread reads establish happens-before instead of racing the writes.
    func currentBatch() -> LogsBatch? {
        processorQueue.sync { batch }
    }
}

extension DefaultLogBatcher {
    /// Asynchronously ends the current batch and starts a new one.
    ///
    /// The ending session is captured at call time and handed to the delegate, so the batch is attributed
    /// to it even if the session controller has already moved on to another session (or none) by the time
    /// the batch is processed. This never blocks the calling thread.
    ///
    /// - Parameters:
    ///   - endingSession: the session the pending logs belong to.
    func forceEndCurrentBatch(endingSession: EmbraceSession?) {
        processorQueue.async {
            self.renewBatch(session: endingSession)
        }
    }

    func renewBatch(withLogs logs: [EmbraceLog] = []) {
        renewBatch(withLogs: logs, session: nil)
    }

    private func renewBatch(withLogs logs: [EmbraceLog] = [], session: EmbraceSession?) {
        guard let batch = self.batch else {
            return
        }

        cancelBatchDeadline()
        delegate?.batchFinished(withLogs: batch.logs, session: session)

        self.batch = .init(limits: logBatchLimits, logs: logs)

        if logs.isEmpty == false {
            renewBatchDeadline(with: logBatchLimits)
        }
    }

    func addLog(_ log: EmbraceLog) {
        processorQueue.async {
            if let batch = self.batch {
                let result = batch.add(log: log)
                switch result {
                case .success(let state):
                    if state == .closed {
                        self.renewBatch()
                    } else if self.batchDeadlineWorkItem == nil {
                        self.renewBatchDeadline(with: self.logBatchLimits)
                    }
                case .failure:
                    self.renewBatch(withLogs: [log])
                }
            } else {
                self.batch = .init(limits: self.logBatchLimits, logs: [log])
                self.renewBatchDeadline(with: self.logBatchLimits)
            }
        }
    }

    func renewBatchDeadline(with logLimits: LogBatchLimits) {
        self.batchDeadlineWorkItem?.cancel()

        let item = DispatchWorkItem { [weak self] in
            self?.renewBatch()
        }

        scheduleDeadline(logBatchLimits.maxBatchAge, item)

        self.batchDeadlineWorkItem = item
    }

    func cancelBatchDeadline() {
        self.batchDeadlineWorkItem?.cancel()
        self.batchDeadlineWorkItem = nil
    }
}
