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

        public override convenience init() {
            self.init(baseURL: nil, developmentBaseURL: nil, configBaseURL: nil)
        }

        @objc public init(baseURL: String? = nil, developmentBaseURL: String? = nil, configBaseURL: String? = nil) {
            self.baseURL = baseURL ?? "data.emb-api.com"
            self.developmentBaseURL = developmentBaseURL ?? "data-dev.emb-api.com"
            self.configBaseURL = configBaseURL ?? "config.emb-api.com"
        }
    }
}
