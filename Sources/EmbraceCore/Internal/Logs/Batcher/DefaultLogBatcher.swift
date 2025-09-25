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
    func batchFinished(withLogs logs: [EmbraceLog])
}

protocol LogBatcher: AnyObject {
    func addLog(_ log: EmbraceLog)
    func renewBatch(withLogs logRecords: [EmbraceLog])
    func forceEndCurrentBatch(waitUntilFinished: Bool)

    var logBatchLimits: LogBatchLimits { get }
    var delegate: LogBatcherDelegate? { get set }
    var batch: LogsBatch? { get }
}

class DefaultLogBatcher: LogBatcher {
    let logBatchLimits: LogBatchLimits
    private let processorQueue: DispatchQueue

    weak var delegate: LogBatcherDelegate?

    private var batchDeadlineWorkItem: DispatchWorkItem?
    var batch: LogsBatch?

    init(
        logBatchLimits: LogBatchLimits = LogBatchLimits(),
        processorQueue: DispatchQueue = .init(label: "io.embrace.logBatcher")
    ) {
        self.logBatchLimits = logBatchLimits
        self.processorQueue = processorQueue
    }
}

extension DefaultLogBatcher {
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

        cancelBatchDeadline()
        delegate?.batchFinished(withLogs: batch.logs)

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

        let lifespan = Int(logBatchLimits.maxBatchAge * 1000)
        let lifeInSeconds = DispatchTimeInterval.milliseconds(lifespan)
        processorQueue.asyncAfter(deadline: .now() + lifeInSeconds, execute: item)

        self.batchDeadlineWorkItem = item
    }

    func cancelBatchDeadline() {
        self.batchDeadlineWorkItem?.cancel()
        self.batchDeadlineWorkItem = nil
    }
}
