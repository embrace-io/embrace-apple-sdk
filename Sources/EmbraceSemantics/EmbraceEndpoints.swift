//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// Endpoints the Embrace SDK will use to upload data and fetch the remote configurations.
public struct EmbraceEndpoints {

    /// The base URL to upload session data.
    public let baseURL: String

    /// The base URL to retrieve the remote config.
    public let configBaseURL: String

    /// Initializer that allows for custom endpoints.
    /// - Parameters:
    ///   - baseURL: Endpoint for session data upload.
    ///   - configBaseURL: Endpoint to fetch the remote config.
    public init(baseURL: String, configBaseURL: String) {
        self.baseURL = baseURL
        self.configBaseURL = configBaseURL
    }

    /// Convenience initializer that uses the default Embrace endpoints for the given `appId`.
    public init(appId: String) {
        self.init(
            baseURL: "https://a-\(appId).data.emb-api.com",
            configBaseURL: "https://a-\(appId).config.emb-api.com"
        )
    }
}
