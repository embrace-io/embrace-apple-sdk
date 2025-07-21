//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceStorageInternal
    import EmbraceUploadInternal
#endif

// used for tests
protocol SessionUploader {
    func uploadSession(_ session: EmbraceSession, storage: EmbraceStorage, upload: EmbraceUpload)
}

class DefaultSessionUploader: SessionUploader {
    func uploadSession(_ session: EmbraceSession, storage: EmbraceStorage, upload: EmbraceUpload) {
        UnsentDataHandler.sendSession(session, storage: storage, upload: upload)
    }
}
