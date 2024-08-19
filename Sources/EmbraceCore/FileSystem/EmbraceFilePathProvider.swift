//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal

class EmbraceFilePathProvider: FilePathProvider {
    let partitionId: String
    let appGroupId: String?

    /// - Parameters:
    ///   - partitionId: The base directory this file path provider should use.
    ///   - appGroupId: An optional app group identifier to use if the provider should create file paths in the app group container.
    init(partitionId: String, appGroupId: String?) {
        self.partitionId = partitionId
        self.appGroupId = appGroupId
    }

    func fileURL(for scope: String, name: String) -> URL? {
        return directoryURL(for: scope)?.appendingPathComponent(name)
    }

    func directoryURL(for scope: String) -> URL? {
        let captureURL = EmbraceFileSystem.captureDirectoryURL(
            partitionIdentifier: partitionId,
            appGroupId: appGroupId)
        return captureURL?.appendingPathComponent(scope)
    }
}
