//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceUploadInternal
import Foundation

class SpyEmbraceLogUploader: EmbraceLogUploader {
    typealias LogCompletion = (Result<(), Error>) -> Void

    /// Log upload state, guarded because `uploadLog` can be called from a different thread than the test.
    private struct LogState {
        var didCallUploadLogCount = 0
        var logPayloadTypes: String? = nil
        var logData: Data? = nil
        var stubbedLogCompletion: (Result<(), Error>)?
        var shouldCompleteLogUploads = true
        var pendingLogCompletions: [LogCompletion?] = []
    }
    private let logState = EmbraceMutex(LogState())

    var didCallUploadLog: Bool { didCallUploadLogCount > 0 }
    var didCallUploadLogCount: Int { logState.withLock { $0.didCallUploadLogCount } }
    var logPayloadTypes: String? { logState.withLock { $0.logPayloadTypes } }
    var logData: Data? { logState.withLock { $0.logData } }
    var stubbedLogCompletion: (Result<(), Error>)? {
        get { logState.withLock { $0.stubbedLogCompletion } }
        set { logState.withLock { $0.stubbedLogCompletion = newValue } }
    }
    /// When `false`, log upload completions are stored as pending instead of being called.
    var shouldCompleteLogUploads: Bool {
        get { logState.withLock { $0.shouldCompleteLogUploads } }
        set { logState.withLock { $0.shouldCompleteLogUploads = newValue } }
    }
    var pendingLogCompletionsCount: Int { logState.withLock { $0.pendingLogCompletions.count } }

    /// Removes the oldest pending log upload completion and calls it with the given result.
    /// The completion is called outside the lock, since it can trigger another `uploadLog` call.
    func completeNextPendingLogUpload(with result: Result<(), Error> = .success(())) {
        let completion = logState.withLock { state -> LogCompletion?? in
            state.pendingLogCompletions.isEmpty ? nil : state.pendingLogCompletions.removeFirst()
        }
        completion??(result)
    }

    func uploadLog(id: String, data: Data, payloadTypes: String, completion: ((Result<(), Error>) -> Void)?) {
        let resultToComplete: Result<(), Error>? = logState.withLock { state in
            state.logPayloadTypes = payloadTypes
            state.logData = data

            // the completion is stored before the counter is increased, so anything observing the counter
            // can safely access the pending completion
            if !state.shouldCompleteLogUploads {
                state.pendingLogCompletions.append(completion)
            }
            state.didCallUploadLogCount += 1

            return state.shouldCompleteLogUploads ? (state.stubbedLogCompletion ?? .success(())) : nil
        }

        if let resultToComplete {
            completion?(resultToComplete)
        }
    }

    var didCallUploadAttachment = false
    var didCallUploadAttachmentCount = 0
    var stubbedAttachmentCompletion: (Result<(), Error>)?
    func uploadAttachment(id: String, data: Data, completion: ((Result<(), any Error>) -> Void)?) {
        didCallUploadAttachmentCount += 1
        didCallUploadAttachment = true
        if let result = stubbedAttachmentCompletion {
            completion?(result)
        }
    }

}
