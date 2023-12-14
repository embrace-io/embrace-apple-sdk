//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

extension Embrace {
    @objc(EMBEndpoints)
    public class Endpoints: NSObject {

        /// The base URL to upload session data
        @objc public let baseURL: String

        /// The base URL to upload session data while a debugger is attached
        @objc public let developmentBaseURL: String

        /// The base URL to retrieve remote config
        @objc public let configBaseURL: String

        @objc public init(baseURL: String, developmentBaseURL: String, configBaseURL: String) {
            self.baseURL = baseURL
            self.developmentBaseURL = developmentBaseURL
            self.configBaseURL = configBaseURL
        }
    }
}

internal extension Embrace.Endpoints {
    @objc convenience init(appId: String) {
        self.init(
            baseURL: "https://a-\(appId).data.emb-api.com",
            developmentBaseURL: "https://a-\(appId).data-dev.emb-api.com",
            configBaseURL: "https://a-\(appId).config.emb-api.com")
    }
}
