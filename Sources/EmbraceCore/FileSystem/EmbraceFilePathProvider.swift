//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal

class EmbraceFilePathProvider: FilePathProvider {
    let appId: String
    let appGroupIdentifier: String?

    init(appId: String, appGroupIdentifier: String?) {
        self.appId = appId
        self.appGroupIdentifier = appGroupIdentifier
    }

    func fileURL(for scope: String, name: String) -> URL? {
        return directoryURL(for: scope)?.appendingPathComponent(name)
    }

    func directoryURL(for scope: String) -> URL? {
        let captureURL = EmbraceFileSystem.captureDirectoryURL(appId: appId, appGroupId: appGroupIdentifier)
        return captureURL?.appendingPathComponent(scope)
    }
}
