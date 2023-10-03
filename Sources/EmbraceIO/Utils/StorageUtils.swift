//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceStorage

class StorageUtils {

    static func directory(platform: EmbracePlatform) -> FileManager.SearchPathDirectory {
        switch platform {
        case .tvOS: return FileManager.SearchPathDirectory.cachesDirectory
        default: return FileManager.SearchPathDirectory.applicationSupportDirectory
        }
    }

    static func basePath(platform: EmbracePlatform) -> String? {
        let directory = directory(platform: platform)
        return NSSearchPathForDirectoriesInDomains(directory, FileManager.SearchPathDomainMask.userDomainMask, true).first
    }

    static func path(appId: String) -> String {
        return "/\(Constants.rootFolderName)/\(Constants.versionFolderName)/\(appId)/storage/"
    }

    static func createStorage(options: EmbraceOptions) -> EmbraceStorage? {
        let basePath = basePath(platform: options.platform)
        let path = path(appId: options.appId)

        guard let basePath = basePath,
              let baseUrl = URL(string: basePath + path) else {
            print("Error initializing Embrace Storage!")
            return nil
        }

        do {
            let storageOptions = EmbraceStorage.Options(baseUrl: baseUrl, fileName: "db.sqlite")
            return try EmbraceStorage(options: storageOptions)
        } catch {
            print("Error initializing Embrace Storage: " + error.localizedDescription)
        }

        return nil
    }
}
