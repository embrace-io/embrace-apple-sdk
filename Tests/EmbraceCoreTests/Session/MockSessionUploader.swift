//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceStorageInternal
import EmbraceUploadInternal

@testable import EmbraceCore

class MockSessionUploader: SessionUploader {

    var didCallUploadSession: Bool = false
    var uploadedSession: EmbraceSession? = nil

    func uploadSession(_ session: EmbraceSession, storage: EmbraceStorage, upload: EmbraceUpload) {
        didCallUploadSession = true
        uploadedSession = session
    }
}
