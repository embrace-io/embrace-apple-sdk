//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal

/// Class used to provide file paths to help when capturing data.
/// It can be beneficial to pass a filepath to an external instrumentation, like crash reports,
/// that can then be read from later.
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

    /// Returns a file URL for the given scope and name.
    /// - Parameters:
    ///   - scope: The directory scope to create this file URL in.
    ///   - name: The name of the file.
    func fileURL(for scope: String, name: String) -> URL? {
        return directoryURL(for: scope)?.appendingPathComponent(name)
    }

    /// Returns a directory URL for the given scope.
    /// - Parameters:
    ///   - scope: The directory scope to create a reference to
    func directoryURL(for scope: String) -> URL? {
        let captureURL = EmbraceFileSystem.captureDirectoryURL(
            partitionIdentifier: partitionId,
            appGroupId: appGroupId)
        return captureURL?.appendingPathComponent(scope)
    }
}
