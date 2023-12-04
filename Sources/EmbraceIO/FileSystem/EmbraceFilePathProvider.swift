//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon

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
        let collectionURL = EmbraceFileSystem.collectionDirectoryURL(appId: appId, appGroupId: appGroupIdentifier)
        return collectionURL?.appendingPathComponent(scope)
    }
}
