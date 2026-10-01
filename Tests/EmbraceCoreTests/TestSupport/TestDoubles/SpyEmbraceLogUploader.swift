//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceUploadInternal
import Foundation

class SpyEmbraceLogUploader: EmbraceLogUploader {
    var didCallUploadLog = false
    var didCallUploadLogCount = 0
    var logPayloadTypes: String? = nil
    var stubbedLogCompletion: (Result<(), Error>)?
    /// When `false`, log upload completions are stored in `pendingLogCompletions` instead of being called.
    var shouldCompleteLogUploads = true
    var pendingLogCompletions: [((Result<(), Error>) -> Void)?] = []
    func uploadLog(id: String, data: Data, payloadTypes: String, completion: ((Result<(), Error>) -> Void)?) {
        didCallUploadLogCount += 1
        didCallUploadLog = true
        logPayloadTypes = payloadTypes

        guard shouldCompleteLogUploads else {
            pendingLogCompletions.append(completion)
            return
        }

        completion?(stubbedLogCompletion ?? .success(()))
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
