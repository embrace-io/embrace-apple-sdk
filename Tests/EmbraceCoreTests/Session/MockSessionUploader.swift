//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//
    
@testable import EmbraceCore
import EmbraceCommonInternal
import EmbraceStorageInternal
import EmbraceUploadInternal

class MockSessionUploader: SessionUploader {

    var didCallUploadSession: Bool = false
    var uploadedSession: EmbraceSession? = nil

    func uploadSession(_ session: EmbraceSession, storage: EmbraceStorage, upload: EmbraceUpload) {
        didCallUploadSession = true
        uploadedSession = session
    }
}
