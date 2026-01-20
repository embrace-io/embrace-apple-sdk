//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if COCOAPODS
    import EmbraceIO
#else
    import EmbraceCore
#endif

extension Embrace.Endpoints {
    static func fromInfoPlist() -> Embrace.Endpoints? {
        guard let endpoints = Bundle.main.infoDictionary?["EmbraceEndpoints"] as? [String: String],
            let baseURL = value(from: endpoints, key: "baseURL"),
            let configBaseURL = value(from: endpoints, key: "configBaseURL")
        else {
            return nil
        }

        return Embrace.Endpoints(
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
