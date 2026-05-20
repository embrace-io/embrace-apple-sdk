//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceIO
import Foundation

extension EmbraceEndpoints {
    static func fromInfoPlist() -> EmbraceEndpoints? {
        guard let endpoints = Bundle.main.infoDictionary?["EmbraceEndpoints"] as? [String: String],
            let baseURL = value(from: endpoints, key: "baseURL"),
            let configBaseURL = value(from: endpoints, key: "configBaseURL")
        else {
            return nil
        }

        return EmbraceEndpoints(
            baseURL: baseURL,
            configBaseURL: configBaseURL
        )
    }

    private static func value(from endpoints: [String: String], key: String) -> String? {
        guard let value = endpoints[key], !value.isEmpty else {
            return nil
        }

        let scheme = value.contains("localhost") || value.contains("127.0.0.1") ? "http://" : "https://"
        return scheme + value
    }
}
