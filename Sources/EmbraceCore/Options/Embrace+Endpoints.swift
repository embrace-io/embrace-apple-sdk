//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

extension Embrace {

    /// Class used to configure the endpoints `Embrace` will use to upload data and fetch the remote configurations.
    @objc(EMBEndpoints)
    public class Endpoints: NSObject {

        /// The base URL to upload session data
        @objc public let baseURL: String

        /// The base URL to retrieve remote config
        @objc public let configBaseURL: String

        @available(*, deprecated, message: "Development base URL is not used anymore.")
        @objc public let developmentBaseURL: String = ""

        /// Initializer that allows for custom endpoints.
        /// - Note: If you wish to use the default endpoints please refer to the convenience initializer: `init(appId: String)`.
        /// - Parameters:
        ///   - baseURL: Endpoint for session data upload
        ///   - configBaseURL: Endpoint to fetch the remote config
        @objc public init(baseURL: String, configBaseURL: String) {
            self.baseURL = baseURL
            self.configBaseURL = configBaseURL
        }

        /// Initializer that allows for custom endpoints.
        /// - Note: If you wish to use the default endpoints please refer to the convenience initializer: `init(appId: String)`.
        /// - Parameters:
        ///   - baseURL: Endpoint for session data upload
        ///   - developmentBaseURL: Endpoint for session data upload while debugging
        ///   - configBaseURL: Endpoint to fetch the remote config
        @available(*, deprecated, message: "Use `init(baseURL:configBaseURL)` instead.")
        @objc public init(baseURL: String, developmentBaseURL: String, configBaseURL: String) {
            self.baseURL = baseURL
            self.configBaseURL = configBaseURL
        }
    }
}

extension Embrace.Endpoints {
    /// Convenience initializer that will use the default endpoints for a given `appId`.
    /// - Parameter appId: The `appId` of the project.
    @objc convenience init(appId: String) {
        self.init(
            baseURL: "https://a-\(appId).data.emb-api.com",
            configBaseURL: "https://a-\(appId).config.emb-api.com"
        )
    }
}
