//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceCommonInternal
#endif

public extension EmbraceUpload {

    class CacheOptions {
        /// Determines where the db is going to be
        let storageMechanism: StorageMechanism

        /// All operations are executed inside a background tasks if enabled
        public let enableBackgroundTasks: Bool

        /// Determines the maximum amount of cached requests that will be cached. Use 0 to disable.
        public let cacheLimit: UInt

        /// Determines the maximum amount of days a request will be cached. Use 0 to disable.
        public let cacheDaysLimit: UInt

        /// If enabled, the cache will be emptied when created
        public let resetCache: Bool

        public init(
            storageMechanism: StorageMechanism,
            enableBackgroundTasks: Bool = true,
            cacheLimit: UInt = 0,
            cacheDaysLimit: UInt = 7,
            resetCache: Bool = false
        ) {
            self.storageMechanism = storageMechanism
            self.enableBackgroundTasks = enableBackgroundTasks
            self.cacheLimit = cacheLimit
            self.cacheDaysLimit = cacheDaysLimit
            self.resetCache = resetCache
        }
    }
}
