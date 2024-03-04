//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceUpload

class SpyEmbraceLogUploader: EmbraceLogUploader {
    var didCallUploadLog = false
    var didCallUploadLogCount = 0
    var stubbedCompletion: (Result<(), Error>)?
    func uploadLog(id: String, data: Data, completion: ((Result<(), Error>) -> Void)?) {
        didCallUploadLogCount += 1
        didCallUploadLog = true
        if let result = stubbedCompletion {
            completion?(result)
        }
    }
}
