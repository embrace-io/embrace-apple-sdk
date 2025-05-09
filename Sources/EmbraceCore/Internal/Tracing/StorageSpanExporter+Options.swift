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
        let validators: [SpanDataValidator]

        init(
            storage: EmbraceStorage,
            sessionController: SessionControllable,
            validators: [SpanDataValidator] = .default
        ) {
            self.storage = storage
            self.sessionController = sessionController
            self.validators = validators
        }
    }
}
