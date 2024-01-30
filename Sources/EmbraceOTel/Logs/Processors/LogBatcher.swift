//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon
import OpenTelemetrySdk

protocol LogBatcherDelegate: AnyObject {
    func didChangeState(batch: LogBatch)
}

protocol LogBatcher {
    func addLogRecord(logRecord: ReadableLogRecord)
    func updateCurrentBatch(to newState: LogBatch.State)
    func updateLimits(_ newLimits: BatchLimits)
}

class DefaultLogBatcher: LogBatcher {
    private let repository: LogRepository
    private let processorQueue: DispatchQueue

    private weak var delegate: LogBatcherDelegate?

    @ThreadSafe
    private var limits: BatchLimits
    @ThreadSafe
    private var currentBatchId: BatchId?
    private var timer: Timer = .init()

    init(
        repository: LogRepository,
        delegate: LogBatcherDelegate,
        processorQueue: DispatchQueue = .init(label: "io.embrace.logBatcher", qos: .utility),
        limits: BatchLimits
    ) {
        self.repository = repository
        self.limits = limits
        self.processorQueue = processorQueue
        self.delegate = delegate
    }

    func addLogRecord(logRecord: ReadableLogRecord) {
        ensureBatchIsValid { batch in
            guard case .success(let batch) = batch else {
                return
            }
            self.repository.addLogToBatch(withId: batch.id, log: logRecord) { result in
                switch result {
                case .success(let batch):
                    break
                case .failure(let error):
                    ConsoleLog.error(error.localizedDescription)
                }
            }
        }
    }

    func updateCurrentBatch(to newState: LogBatch.State) {
        guard let currentBatchId = currentBatchId else {
            return
        }
        processorQueue.async {
            self.repository.updateStateToBatch(withId: currentBatchId, state: .closed) { result in
                switch result {
                case .success(let batch):
                    self.delegate?.didChangeState(batch: batch)
                case .failure(let error):
                    ConsoleLog.error(error.localizedDescription)
                }
            }

        }
    }

    func updateLimits(_ newLimits: BatchLimits) {
        limits = newLimits
        ensureBatchIsValid()
    }
}

// MARK: Private Methods
private extension LogBatcher {
    func startNewBatch(completion: ((Result<LogBatch, Error>) -> Void)? = nil) {
        processorQueue.async {
            self.repository.createBatch { result in
                switch result {
                case .success(let batch):
                    self.resetTimer()
                    self.currentBatchId = batch.id
                    completion?(.success(batch))
                case .failure(let error):
                    completion?(.failure(error))
                }
            }
        }
    }

    func resetTimer() {
        timer.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: limits.maxAge, repeats: false) { [weak self] _ in
            self?.updateCurrentBatch(to: .closed)
        }
    }

    func ensureBatchIsValid(completion: ((Result<LogBatch, Error>) -> Void)? = nil) {
        guard let currentBatchId = currentBatchId else {
            startNewBatch(completion: completion)
            return
        }
        processorQueue.async {
            self.repository.getBatch(byId: currentBatchId) { result in
                switch result {
                case .success(let batch):
                    let isBatchFull = batch.logs.count >= self.limits.maxLogsPerBatch
                    let isBatchOld = -batch.creationDate.timeIntervalSinceNow > self.limits.maxAge
                    let isBatchNotOpen = batch.state != .open

                    if isBatchFull || isBatchOld || isBatchNotOpen {
                        if batch.state == .open {
                            self.updateCurrentBatch(to: .closed)
                        }
                        self.startNewBatch(completion: completion)
                    }
                case .failure(let error):
                    ConsoleLog.error(error.localizedDescription)
                }
            }
        }
    }
}
