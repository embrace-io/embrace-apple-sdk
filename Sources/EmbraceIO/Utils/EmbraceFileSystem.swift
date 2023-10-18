//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public struct EmbraceFileSystem {
    static let rootFolderName = "io.embrace.data"
    static let versionFolderName = "v4"
    static let storageFolderName = "storage"
    static let uploadsFolderName = "uploads"
    static let crashesFolderName = "crashes"

    static func baseDirectory(appGroupId: String? = nil, forceCachesDirectory: Bool = false) -> URL? {
        // if the app group identifier is set, we use the shared container provided by the OS
        if let appGroupId = appGroupId {
            return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId)
        }

        let directory = forceCachesDirectory ?
            FileManager.SearchPathDirectory.cachesDirectory :
            FileManager.SearchPathDirectory.applicationSupportDirectory

        if let path = NSSearchPathForDirectoriesInDomains(directory, FileManager.SearchPathDomainMask.userDomainMask, true).first {
            return URL(fileURLWithPath: path, isDirectory: true)
        }

        return nil
    }

    static func directoryURL(name: String, appId: String, appGroupId: String? = nil, forceCachesDirectory: Bool = false) -> URL? {
        guard let baseURL = baseDirectory(appGroupId: appGroupId, forceCachesDirectory: forceCachesDirectory) else {
            return nil
        }

        return baseURL.appendingPathComponent("\(rootFolderName)/\(versionFolderName)/\(appId)/\(name)")
    }

    public static func storageDirectoryURL(
        appId: String,
        appGroupId: String? = nil,
        forceCachesDirectory: Bool = false) -> URL? {
        return directoryURL(name: storageFolderName, appId: appId, appGroupId: appGroupId, forceCachesDirectory: forceCachesDirectory)
    }

    public static func uploadsDirectoryPath(
        appId: String,
        appGroupId: String? = nil,
        forceCachesDirectory: Bool = false) -> URL? {
        return directoryURL(name: uploadsFolderName, appId: appId, appGroupId: appGroupId, forceCachesDirectory: forceCachesDirectory)
    }

    public static func crashesDirectoryPath(
        appId: String,
        appGroupId: String? = nil,
        forceCachesDirectory: Bool = false) -> URL? {
        return directoryURL(name: crashesFolderName, appId: appId, appGroupId: appGroupId, forceCachesDirectory: forceCachesDirectory)
    }
}
