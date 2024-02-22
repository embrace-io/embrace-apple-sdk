//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

extension URL {
    static func endpoint(basePath: String, apiPath: String) -> URL? {
        var components = URLComponents(string: basePath)
        components?.path.append(apiPath)
        return components?.url
    }

    static func sessionsEndpoint(basePath: String) -> URL? {
        return endpoint(basePath: basePath, apiPath: "/v1/log/sessions")
    }

    static func blobsEndpoint(basePath: String) -> URL? {
        return endpoint(basePath: basePath, apiPath: "/v1/log/blobs")
    }

    static func logsEndpoint(basePath: String) -> URL? {
        return endpoint(basePath: basePath, apiPath: "/v2/log/logs")
    }
}
