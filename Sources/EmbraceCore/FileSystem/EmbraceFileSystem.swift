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
            // TODO: should we throw error and allow return type to be non-optional?
            return nil
        }
    }

    static func rootURL(appGroupId: String? = nil) -> URL? {
        return systemDirectory(appGroupId: appGroupId)?.appendingPathComponent(rootDirectoryName)
    }

    /// Returns a subpath within the root directory of the Embrace SDK.
    /// ```
    /// io.embrace.data/<version>/<app-id>/<name>
    /// ```
    static func directoryURL(name: String, appId: String, appGroupId: String? = nil) -> URL? {
        guard let baseURL = systemDirectory(appGroupId: appGroupId) else {
            return nil
        }

        let components = [rootDirectoryName, versionDirectoryName, appId, name]
        return baseURL.appendingPathComponent(components.joined(separator: "/"))
    }

    /// Returns the subdirectory for the storage
    /// ```
    /// io.embrace.data/<version>/<app-id>/storage
    /// ```
    static func storageDirectoryURL(
        appId: String,
        appGroupId: String? = nil) -> URL? {
        return directoryURL(name: storageDirectoryName, appId: appId, appGroupId: appGroupId)
    }

    /// Returns the subdirectory for upload data
    /// ```
    /// io.embrace.data/<version>/<app-id>/uploads
    /// ```
    static func uploadsDirectoryPath(
        appId: String,
        appGroupId: String? = nil) -> URL? {
        return directoryURL(name: uploadsDirectoryName, appId: appId, appGroupId: appGroupId)
    }

    /// Returns the subdirectory for data capture
    /// ```
    /// io.embrace.data/<version>/<app-id>/capture
    /// ```
    static func captureDirectoryURL(appId: String, appGroupId: String? = nil) -> URL? {
        return directoryURL(name: captureDirectoryName, appId: appId, appGroupId: appGroupId)
    }
}
