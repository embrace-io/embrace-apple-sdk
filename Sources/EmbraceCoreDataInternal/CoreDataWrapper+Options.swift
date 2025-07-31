//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import CoreData
import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

extension CoreDataWrapper {

    public class Options {
        /// Determines where the db is going to be stored
        public let storageMechanism: StorageMechanism

        /// All operations are executed inside a background tasks if enabled
        public let enableBackgroundTasks: Bool

        /// Array on NSEntityDescriptions that define the db model
        public let entities: [NSEntityDescription]

        public init(
            storageMechanism: StorageMechanism,
            enableBackgroundTasks: Bool = true,
            entities: [NSEntityDescription]
        ) {
            self.storageMechanism = storageMechanism
            self.enableBackgroundTasks = enableBackgroundTasks
            self.entities = entities
        }
    }
}
