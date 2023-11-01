//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public struct EmbraceFileSystem {
    static let rootFolderName = "io.embrace.data"
    static let versionFolderName = "v6"
    static let storageFolderName = "storage"
    static let uploadsFolderName = "uploads"
    static let crashesFolderName = "crashes"

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

    static func dataURL(appGroupId: String? = nil) -> URL? {
        return systemDirectory(appGroupId: appGroupId)?.appendingPathComponent(rootFolderName)
    }

    /// Returns the path to the root directory of the Embrace SDK.
    static func directoryURL(name: String, appId: String, appGroupId: String? = nil) -> URL? {
        guard let baseURL = systemDirectory(appGroupId: appGroupId) else {
            return nil
        }

        let components = [rootFolderName, versionFolderName, appId, name]
        return baseURL.appendingPathComponent(components.joined(separator: "/"))
    }

    static func storageDirectoryURL(
        appId: String,
        appGroupId: String? = nil) -> URL? {
        return directoryURL(name: storageFolderName, appId: appId, appGroupId: appGroupId)
    }

    static func uploadsDirectoryPath(
        appId: String,
        appGroupId: String? = nil) -> URL? {
        return directoryURL(name: uploadsFolderName, appId: appId, appGroupId: appGroupId)
    }

    static func crashesDirectoryPath(
        appId: String,
        appGroupId: String? = nil) -> URL? {
        return directoryURL(name: crashesFolderName, appId: appId, appGroupId: appGroupId)
    }
}
