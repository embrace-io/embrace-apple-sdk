//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceStorage

public extension StorageSpanExporter {
    class Options {

        let storage: EmbraceStorage

        init(storage: EmbraceStorage) {
            self.storage = storage
        }
    }
}
