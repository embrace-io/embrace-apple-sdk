//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

extension URL {
    static func endpoint(basePath: String, apiPath: String) -> URL? {
        var components = URLComponents(string: basePath)
        components?.path.append(apiPath)
        return components?.url
    }

    static func spansEndpoint(basePath: String) -> URL? {
        return endpoint(basePath: basePath, apiPath: "/v2/spans")
    }

    static func logsEndpoint(basePath: String) -> URL? {
        return endpoint(basePath: basePath, apiPath: "/v2/logs")
    }

    static func attachmentsEndpoit(basePath: String) -> URL? {
        return endpoint(basePath: basePath, apiPath: "/v2/attachments")
    }
}
