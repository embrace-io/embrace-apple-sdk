//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// Class used to configure a EmbraceStorage instance
public class EmbraceStorageOptions {

    /// URL pointing to the folder where the storage will be saved
    public var baseUrl: URL

    /// URL pointing to the folder where the storage will be saved
    public var fileName: String

    /// Full path to the storage file
    public var filePath: String {
        return baseUrl.appendingPathComponent(fileName).path
    }

    /// Dictionary containing the storage limits per span type
    public var spanLimits: [String: Int] = [:]

    init?(baseUrl: URL, fileName: String) {

        if !baseUrl.isFileURL {
            return nil
        }

        self.baseUrl = baseUrl
        self.fileName = fileName
    }
}
