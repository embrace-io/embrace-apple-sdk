//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceStorageInternal

extension StorageSpanExporter {
    class Options {

        let storage: EmbraceStorage
        let validators: [SpanDataValidator]

        init(storage: EmbraceStorage, validators: [SpanDataValidator] = .default) {
            self.storage = storage
            self.validators = validators
        }
    }
}
