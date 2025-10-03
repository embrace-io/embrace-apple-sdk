//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

extension Embrace {

    /// Class used to configure the endpoints `Embrace` will use to upload data and fetch the remote configurations.
    public struct Endpoints {

        /// The base URL to upload session data
        public let baseURL: String

        /// The base URL to retrieve remote config
        public let configBaseURL: String

        /// Initializer that allows for custom endpoints.
        /// - Note: If you wish to use the default endpoints please refer to the convenience initializer: `init(appId: String)`.
        /// - Parameters:
        ///   - baseURL: Endpoint for session data upload
        ///   - configBaseURL: Endpoint to fetch the remote config
        public init(baseURL: String, configBaseURL: String) {
            self.baseURL = baseURL
            self.configBaseURL = configBaseURL
        }
    }
}

extension Embrace.Endpoints {
    /// Convenience initializer that will use the default endpoints for a given `appId`.
    /// - Parameter appId: The `appId` of the project.
    init(appId: String) {
        self.init(
            baseURL: "https://a-\(appId).data.emb-api.com",
            configBaseURL: "https://a-\(appId).config.emb-api.com"
        )
    }
}
