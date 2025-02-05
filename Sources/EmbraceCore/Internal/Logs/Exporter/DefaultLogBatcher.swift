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

protocol LogBatcher {
    func addLogRecord(logRecord: ReadableLogRecord)
    func renewBatch(withLogs logRecords: [EmbraceLog])
    func forceEndCurrentBatch()
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

    func addLogRecord(logRecord: ReadableLogRecord) {
        processorQueue.async {
            let record = self.repository.createLog(
                id: LogIdentifier(),
                processId: ProcessIdentifier.current,
                severity: logRecord.severity?.toLogSeverity() ?? .info,
                body: logRecord.body?.description ?? "",
                timestamp: logRecord.timestamp,
                attributes: logRecord.attributes
            )
            self.addLogToBatch(record)
        }
    }
}

internal extension DefaultLogBatcher {
    func forceEndCurrentBatch() {
        processorQueue.async {
            self.renewBatch()
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
