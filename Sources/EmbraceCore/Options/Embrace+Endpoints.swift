//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

extension Embrace {
    @objc(EMBEndpoints)
    /// Class used to configure the endpoints `Embrace` will use to upload data and fetch the remote configurations.
    public class Endpoints: NSObject {

        /// The base URL to upload session data
        @objc public let baseURL: String

        /// The base URL to upload session data while a debugger is attached
        @objc public let developmentBaseURL: String

        /// The base URL to retrieve remote config
        @objc public let configBaseURL: String

        /// Initializer that allows for custom endpoints.
        /// - Note: If you wish to use the default endpoints please refer to the convenience initializer: `init(appId: String)`.
        /// - Parameters:
        ///   - baseURL: Endpoint for session data upload
        ///   - developmentBaseURL: Endpoint for session data upload while debugging
        ///   - configBaseURL: Endpoint to fetch the remote config
        @objc public init(baseURL: String, developmentBaseURL: String, configBaseURL: String) {
            self.baseURL = baseURL
            self.developmentBaseURL = developmentBaseURL
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
            developmentBaseURL: "https://data-dev.emb-api.com",
            configBaseURL: "https://a-\(appId).config.emb-api.com")
    }
}
