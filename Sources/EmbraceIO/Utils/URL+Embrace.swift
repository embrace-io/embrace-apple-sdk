//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

extension URL {
    static let apiVersion = "v1"

    static func endpoint(basePath: String, apiPath: String) -> URL? {
        return URL(string: String(format: "%@/\(apiVersion)/%@", basePath, apiPath))
    }

    static func sessionsEndpoint(basePath: String) -> URL? {
        return endpoint(basePath: basePath, apiPath: "log/sessions")
    }

    static func blobsEndpoint(basePath: String) -> URL? {
        return endpoint(basePath: basePath, apiPath: "log/blobs")
    }
}
