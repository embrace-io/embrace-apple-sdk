//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// Object passed to each collector during setup
@objc public final class CollectorContext: NSObject {

    public let appId: String
    public let sdkVersion: String
    public let filePathProvider: FilePathProvider

    public init(appId: String, sdkVersion: String, filePathProvider: FilePathProvider) {
        self.appId = appId
        self.sdkVersion = sdkVersion
        self.filePathProvider = filePathProvider
    }

}
