//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceStorageInternal
    import EmbraceCommonInternal
    import EmbraceConfiguration
#endif

protocol LogBatcherDelegate: AnyObject {
    func batchFinished(withLogs logs: [EmbraceLog], sessionId: EmbraceIdentifier?)
    var limits: LogsLimits { get set }
}

protocol LogBatcher: AnyObject {
    func addLogRecord(logRecord: ReadableLogRecord)
    func renewBatch(withLogs logRecords: [EmbraceLog])
    func forceEndCurrentBatch(sessionId: EmbraceIdentifier?)
    var limits: LogsLimits { get }
}

class DefaultLogBatcher: LogBatcher {
    private let repository: LogRepository
    private let processorQueue: DispatchQueue
    private let logLimits: LogBatchLimits

    private weak var delegate: LogBatcherDelegate?
    private var batchDeadlineWorkItem: DispatchWorkItem?
    private var batch: LogsBatch?

    var limits: LogsLimits {
        delegate?.limits ?? .init()
    }

    /// Schedules the work item that ends the current batch once it reaches its maximum age.
    /// It's called on `processorQueue`, and the item must run there too.
    typealias DeadlineScheduler = (_ delay: TimeInterval, _ item: DispatchWorkItem) -> Void
    private let scheduleDeadline: DeadlineScheduler

    /// - Parameters:
    ///   - scheduleDeadline: Schedules the batch deadline. It defaults to `asyncAfter` on
    ///     `processorQueue`; tests pass their own so they can fire the deadline themselves.
    init(
        repository: LogRepository,
        logLimits: LogBatchLimits,
        delegate: LogBatcherDelegate,
        processorQueue: DispatchQueue = .init(label: "io.embrace.logBatcher"),
        scheduleDeadline: DeadlineScheduler? = nil
    ) {
        self.repository = repository
        self.logLimits = logLimits
        self.processorQueue = processorQueue
        self.delegate = delegate
        self.scheduleDeadline =
            scheduleDeadline ?? { delay, item in
                let milliseconds = DispatchTimeInterval.milliseconds(Int(delay * 1000))
                processorQueue.asyncAfter(deadline: .now() + milliseconds, execute: item)
            }
    }

    func addLogRecord(logRecord: ReadableLogRecord) {
        processorQueue.async {
            if let record = self.repository.createLog(
                id: EmbraceIdentifier.random,
                processId: ProcessIdentifier.current,
                severity: logRecord.severity?.toLogSeverity() ?? .info,
                body: logRecord.body?.description ?? "",
                timestamp: logRecord.timestamp,
                attributes: logRecord.attributes
            ) {
                self.addLogToBatch(record)
            }
        }
    }
}

extension DefaultLogBatcher {
    /// Asynchronously forces the current batch to end and renews it.
    ///
    /// This method ensures that any pending logs are flushed by renewing the batch.
    /// It never blocks the caller: the work is scheduled on the internal queue.
    ///
    /// - Parameters:
    ///   - sessionId: the identifier of the session the finished batch's logs belong to.
    func forceEndCurrentBatch(sessionId: EmbraceIdentifier? = nil) {
        processorQueue.async {
            self.renewBatchInternal(sessionId: sessionId)
        }
    }

    func renewBatch(withLogs logs: [EmbraceLog] = []) {
        renewBatchInternal(withLogs: logs, sessionId: nil)
    }

    private func renewBatchInternal(withLogs logs: [EmbraceLog] = [], sessionId: EmbraceIdentifier?) {
        guard let batch = self.batch else {
            return
        }
        self.cancelBatchDeadline()
        self.delegate?.batchFinished(withLogs: batch.logs, sessionId: sessionId)
        self.batch = .init(limits: self.logLimits, logs: logs)

        if logs.isEmpty == false {
            self.renewBatchDeadline(with: self.logLimits)
        }
    }

    func addLogToBatch(_ log: EmbraceLog) {
        processorQueue.async {
            if let batch = self.batch {
                let result = batch.add(log: log)
                switch result {
                case .success(let state):
                    if state == .closed {
                        self.renewBatch()
                    } else if self.batchDeadlineWorkItem == nil {
                        self.renewBatchDeadline(with: self.logLimits)
                    }
                case .failure:
                    self.renewBatch(withLogs: [log])
                }
            } else {
                self.batch = .init(limits: self.logLimits, logs: [log])
                self.renewBatchDeadline(with: self.logLimits)
            }
        }
    }

    func renewBatchDeadline(with logLimits: LogBatchLimits) {
        self.batchDeadlineWorkItem?.cancel()

        let item = DispatchWorkItem { [weak self] in
            self?.renewBatch()
        }

        scheduleDeadline(self.logLimits.maxBatchAge, item)

        self.batchDeadlineWorkItem = item
    }

    func cancelBatchDeadline() {
        self.batchDeadlineWorkItem?.cancel()
        self.batchDeadlineWorkItem = nil
    }
}
