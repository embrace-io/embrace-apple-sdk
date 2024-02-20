//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public extension EmbraceStorage {
    enum StorageMechanism {
        case inMemory(name: String)
        case onDisk(baseURL: URL, fileName: String)
    }

    /// Class used to configure a EmbraceStorage instance
    class Options {
        let storageMechanism: StorageMechanism

        /// Dictionary containing the storage limits per span type
        public var spanLimits: [String: Int] = [:]

        /// Determines how many `MetadataRecords` of the `.resource` type can be present at any given time.
        public var resourcesLimit: Int = 100

        /// Determines how many `MetadataRecords` of the `.customProperty` type can be present at any given time.
        public var customPropertiesLimit: Int = 100

        /// Use this initializer to create a storage object that is persisted locally to disk
        /// - Parameters:
        ///   - baseUrl: The URL to the directory this storage object should use to persist data. Must be a URL to a local directory.
        ///   - fileName: The filename that will be used for the file of this storage object on disk.
        public init(baseUrl: URL, fileName: String) {
            precondition(baseUrl.isFileURL, "baseURL must be a fileURL")
            storageMechanism = .onDisk(baseURL: baseUrl, fileName: fileName)
        }

        /// Use this initializer to create an inMemory storage
        /// - Parameter name: The name of the underlying storage object
        public init(named name: String) {
            storageMechanism = .inMemory(name: name)
        }
    }
}

extension EmbraceStorage.Options {
    /// The name of the storage item when using an inMemory storage
    public var name: String? {
        if case let .inMemory(name) = storageMechanism {
            return name
        }
        return nil
    }

    /// URL pointing to the folder where the storage will be saved
    public var baseUrl: URL? {
        if case let .onDisk(baseURL, _) = storageMechanism {
            return baseURL
        }
        return nil
    }

    /// URL pointing to the folder where the storage will be saved
    public var fileName: String? {
        if case let .onDisk(_, name) = storageMechanism {
            return name
        }
        return nil
    }

    /// Full path to the storage file
    public var filePath: String? {
        if case let .onDisk(url, filename) = storageMechanism {
            return url.appendingPathComponent(filename).path
        }
        return nil
    }
}
