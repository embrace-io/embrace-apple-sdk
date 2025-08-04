//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceStorageInternal
#endif

extension StorageSpanExporter {
    class Options {

        let storage: EmbraceStorage
        let sessionController: SessionControllable

        init(
            storage: EmbraceStorage,
            sessionController: SessionControllable
        ) {
            self.storage = storage
            self.sessionController = sessionController
        }
    }
}
