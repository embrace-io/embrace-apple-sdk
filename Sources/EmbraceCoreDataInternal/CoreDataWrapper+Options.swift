//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import CoreData
import EmbraceCommonInternal

public extension CoreDataWrapper {

    class Options {
        /// Determines where the db is going to be stored
        let storageMechanism: StorageMechanism

        /// Array on NSEntityDescriptions that define the db model
        let entities: [NSEntityDescription]

        public init(
            storageMechanism: StorageMechanism,
            entities: [NSEntityDescription]
        ) {
            self.storageMechanism = storageMechanism
            self.entities = entities
        }
    }
}
