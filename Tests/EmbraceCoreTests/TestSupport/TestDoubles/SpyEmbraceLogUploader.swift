//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceUploadInternal
import Foundation

class SpyEmbraceLogUploader: EmbraceLogUploader {
    var didCallUploadLog = false
    var didCallUploadLogCount = 0
    var stubbedLogCompletion: (Result<(), Error>)?
    func uploadLog(id: String, data: Data, completion: ((Result<(), Error>) -> Void)?) {
        didCallUploadLogCount += 1
        didCallUploadLog = true
        if let result = stubbedLogCompletion {
            completion?(result)
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
