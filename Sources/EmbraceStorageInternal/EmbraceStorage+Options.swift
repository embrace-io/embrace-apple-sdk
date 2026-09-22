//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
    import EmbraceCommonInternal
#endif

extension EmbraceStorage {

    /// Class used to configure a EmbraceStorage instance
    public class Options {
        /// Determines where the db is going to be
        public let storageMechanism: StorageMechanism

        /// All operations are executed inside a background tasks if enabled
        public let enableBackgroundTasks: Bool

        /// Dictionary containing the storage limits per span type
        public var spanLimits: [EmbraceType: Int] = [:]

        /// Default storage limit for unspecified span type
        public var spanLimitDefault: Int = 1500

        /// Determines how many `MetadataRecords` of the `.resource` type can be present at any given time.
        public var resourcesLimit: Int = 100

        /// Determines how many `MetadataRecords` of the `.customProperty` type can be present at any given time.
        public var customPropertiesLimit: Int = 100

        /// Determines how many `MetadataRecords` of the `.personaTag` type can be present at any given time.
        public var personaTagsLimit: Int = 10

        /// Use this initializer to create a storage object that is persisted locally to disk
        /// - Parameters:
        ///   - storageMechanism: The StorageMechanism to use
        public init(storageMechanism: StorageMechanism, enableBackgroundTasks: Bool = true) {
            self.storageMechanism = storageMechanism
            self.enableBackgroundTasks = enableBackgroundTasks
        }
    }
}
