//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public extension EmbraceUpload {
    class CacheOptions {
        /// URL pointing to the folder where the upload cache storage will be saved
        public var cacheBaseUrl: URL

        /// Name for the cache storage file
        public var cacheFileName: String

        /// Full path to the storage file
        public var cacheFilePath: String {
            return cacheBaseUrl.appendingPathComponent(cacheFileName).path
        }

        /// Determines the maximum amount of cached requests that will be cached. Use 0 to disable.
        public var cacheLimit: UInt

        /// Determines the maximum amount of days a request will be cached. Use 0 to disable.
        public var cacheDaysLimit: UInt

        /// Determines the maximum cache size in bytes. Use 0 to disable.
        public var cacheSizeLimit: UInt

        public init?(
            cacheBaseUrl: URL,
            cacheFileName: String = "db.sqlite",
            cacheLimit: UInt = 0,
            cacheDaysLimit: UInt = 0,
            cacheSizeLimit: UInt = 0
        ) {
            if !cacheBaseUrl.isFileURL {
                return nil
            }

            self.cacheBaseUrl = cacheBaseUrl
            self.cacheFileName = cacheFileName
            self.cacheLimit = cacheLimit
            self.cacheDaysLimit = cacheDaysLimit
            self.cacheSizeLimit = cacheSizeLimit
        }
    }
}
