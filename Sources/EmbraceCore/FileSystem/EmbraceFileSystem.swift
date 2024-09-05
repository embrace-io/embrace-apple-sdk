//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public struct EmbraceFileSystem {
    static let rootDirectoryName = "io.embrace.data"
    static let versionDirectoryName = "v6"
    static let storageDirectoryName = "storage"
    static let uploadsDirectoryName = "uploads"
    static let crashesDirectoryName = "crashes"
    static let captureDirectoryName = "capture"

    static let defaultPartitionId = "default"

    /// Returns the path to the system directory that is the root directory for storage.
    /// When `appGroupId` is present, will be a URL to an app group container
    /// If not present, will be a path to the user's applicaton support directory.
    ///
    /// - Note: On tvOS, if `appGroupId` is not present this will be a path to the user's Cache directory.
    ///                tvOS is an always connected system an long term persistented data is not permitted
    private static func systemDirectory(appGroupId: String? = nil) -> URL? {
        // if the app group identifier is set, we use the shared container provided by the OS
        if let appGroupId = appGroupId {
            return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId)
        }

        #if os(tvOS)
        //  tvOS is an "always connected" system, therefore Apple does not let data
        //      be stored outside of the "Caches" directory
        //  From https://developer.apple.com/library/archive/documentation/General/Conceptual/AppleTV_PG/index.html#//apple_ref/doc/uid/TP40015241
        //      > Local Storage for Your App Is Limited
        let directory = FileManager.SearchPathDirectory.cachesDirectory
        #else
        let directory = FileManager.SearchPathDirectory.applicationSupportDirectory
        #endif

        do {
            return try FileManager.default.url(for: directory, in: .userDomainMask, appropriateFor: nil, create: true)
        } catch {
            return nil
        }
    }

    static func rootURL(appGroupId: String? = nil) -> URL? {
        return systemDirectory(appGroupId: appGroupId)?.appendingPathComponent(rootDirectoryName)
    }

    /// Returns a subpath within the root directory of the Embrace SDK.
    /// ```
    /// io.embrace.data/<version>/<partition-id>/<name>
    /// ```
    /// - Parameters:
    ///    - name: The name of the subdirectory
    ///    - partitionIdentifier: The main paritition identifier to use
    ///    - appGroupId: The app group identifier if using an app group container.
    static func directoryURL(name: String, partitionId: String, appGroupId: String? = nil) -> URL? {
        guard let baseURL = systemDirectory(appGroupId: appGroupId) else {
            return nil
        }

        let components = [rootDirectoryName, versionDirectoryName, partitionId, name]
        return baseURL.appendingPathComponent(components.joined(separator: "/"))
    }

    /// Returns the subdirectory for the storage
    /// ```
    /// io.embrace.data/<version>/<partition-id>/storage
    /// ```
    static func storageDirectoryURL(
        partitionId: String,
        appGroupId: String? = nil) -> URL? {
        return directoryURL(
            name: storageDirectoryName,
            partitionId: partitionId,
            appGroupId: appGroupId
        )
    }

    /// Returns the subdirectory for upload data
    /// ```
    /// io.embrace.data/<version>/<partition-id>/uploads
    /// ```
    static func uploadsDirectoryPath(
        partitionIdentifier: String,
        appGroupId: String? = nil) -> URL? {
        return directoryURL(
            name: uploadsDirectoryName,
            partitionId: partitionIdentifier,
            appGroupId: appGroupId
        )
    }

    /// Returns the subdirectory for data capture
    /// ```
    /// io.embrace.data/<version>/<partition-id>/capture
    /// ```
    static func captureDirectoryURL(partitionIdentifier: String, appGroupId: String? = nil) -> URL? {
        return directoryURL(
            name: captureDirectoryName,
            partitionId: partitionIdentifier,
            appGroupId: appGroupId
        )
    }
}
