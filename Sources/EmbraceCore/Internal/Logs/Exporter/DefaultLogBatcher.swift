//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

import EmbraceStorage
import EmbraceCommon

protocol LogBatcherDelegate: AnyObject {
    func batchFinished(withLogs logs: [LogRecord])
}

protocol LogBatcher {
    func addLogRecord(logRecord: LogRecord)
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
        processorQueue: DispatchQueue = .init(label: "io.embrace.logBatcher", qos: .utility)
    ) {
        self.repository = repository
        self.logLimits = logLimits
        self.processorQueue = processorQueue
        self.delegate = delegate
    }

    func addLogRecord(logRecord: LogRecord) {
        processorQueue.async {
            self.repository.create(logRecord) { result in
                switch result {
                case .success:
                    self.addLogToBatch(logRecord)
                case .failure(let error):
                    Embrace.logger.error(error.localizedDescription)
                }
            }
        }
    }
}

private extension DefaultLogBatcher {
    func renewBatch(withLogs logRecords: [LogRecord] = []) {
        processorQueue.async {
            guard let batch = self.batch else {
                return
            }
            self.cancelBatchDeadline()
            self.delegate?.batchFinished(withLogs: batch.logs)
            // TODO: Add cleanup step:
            // --> delete reported logs
            self.batch = .init(limits: self.logLimits, logs: logRecords)

            if logRecords.count > 0 {
                self.renewBatchDeadline(with: self.logLimits)
            }
        }
    }

    func addLogToBatch(_ log: LogRecord) {
        processorQueue.async {
            if let batch = self.batch {
                let result = batch.add(logRecord: log)
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
