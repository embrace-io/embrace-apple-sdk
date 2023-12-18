//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCore

extension Embrace.Endpoints {
    static func fromInfoPlist() -> Embrace.Endpoints? {
        guard let endpoints = Bundle.main.infoDictionary?["EmbraceEndpoints"] as? [String: String],
              let baseURL = value(from: endpoints, key: "baseURL"),
              let developmentURL = value(from: endpoints, key: "developmentBaseURL"),
              let configBaseURL = value(from: endpoints, key: "configBaseURL")
        else {
            return nil
        }

        return .init(
            baseURL: baseURL,
            developmentBaseURL: developmentURL,
            configBaseURL: configBaseURL
        )
    }

    private static func value(from endpoints: [String: String], key: String) -> String? {
        guard let value = endpoints[key], !value.isEmpty else {
            return nil
        }

        let scheme = value.contains("localhost") ? "http://" : "https://"
        return scheme + value
    }
}
