//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceStorageInternal
import EmbraceCommonInternal
import OpenTelemetryApi
import OpenTelemetrySdk

protocol LogBatcherDelegate: AnyObject {
    func batchFinished(withLogs logs: [EmbraceLog])
}

protocol LogBatcher: AnyObject {
    func addLogRecord(logRecord: ReadableLogRecord)
    func renewBatch(withLogs logRecords: [EmbraceLog])
    func forceEndCurrentBatch(waitUntilFinished: Bool)
}

class DefaultLogBatcher: LogBatcher {
    private let repository: LogRepository
    private let processorQueue: DispatchQueue
    private let logLimits: LogBatchLimits

    private weak var delegate: LogBatcherDelegate?
    private var batchDeadlineWorkItem: DispatchWorkItem?
    private var batch: LogsBatch?

    init(
        repository: LogRepository,
        logLimits: LogBatchLimits,
        delegate: LogBatcherDelegate,
        processorQueue: DispatchQueue = .init(label: "io.embrace.logBatcher")
    ) {
        self.repository = repository
        self.logLimits = logLimits
        self.processorQueue = processorQueue
        self.delegate = delegate
    }

    func addLogRecord(logRecord: ReadableLogRecord) {
        processorQueue.async {
            if let record = self.repository.createLog(
                id: LogIdentifier(),
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

internal extension DefaultLogBatcher {
    /// Forces the current batch to end and renews it, optionally waiting for completion.
    ///
    /// This method ensures that any pending logs are flushed by rewewing the batch.
    /// If `waitUntilFinished` is `true`, the method blocks the calling thread until the operation on the internal queue completes.
    ///
    /// - Parameters:
    ///   - waitUntilFinished: indicates whether the method should block until the batch operation finishes. Default is `true`.
    func forceEndCurrentBatch(waitUntilFinished: Bool = true) {
        let group = DispatchGroup()

        if waitUntilFinished {
            group.enter()
        }

        processorQueue.async {
            self.renewBatch()
            if waitUntilFinished {
                group.leave()
            }
        }

        if waitUntilFinished {
            group.wait()
        }
    }

    func renewBatch(withLogs logs: [EmbraceLog] = []) {
        guard let batch = self.batch else {
            return
        }
        self.cancelBatchDeadline()
        self.delegate?.batchFinished(withLogs: batch.logs)
        self.batch = .init(limits: self.logLimits, logs: logs)

        if logs.count > 0 {
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

        let lifespan = Int(self.logLimits.maxBatchAge * 1000)
        let lifeInSeconds = DispatchTimeInterval.milliseconds(lifespan)
        processorQueue.asyncAfter(deadline: .now() + lifeInSeconds, execute: item)

        self.batchDeadlineWorkItem = item
    }

    func cancelBatchDeadline() {
        self.batchDeadlineWorkItem?.cancel()
        self.batchDeadlineWorkItem = nil
    }
}
