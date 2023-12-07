//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceIO

extension Embrace.Endpoints {
    static func fromInfoPlist() -> Embrace.Endpoints {
        guard let endpoints = Bundle.main.infoDictionary?["EmbraceEndpoints"] as? [String: String] else {
            return .init()
        }

        return .init(
            baseURL: value(from: endpoints, key: "baseURL"),
            developmentBaseURL: value(from: endpoints, key: "developmentBaseURL"),
            configBaseURL: value(from: endpoints, key: "configBaseURL")
        )
    }

    private static func value(from endpoints: [String: String], key: String) -> String? {
        guard let value = endpoints[key], !value.isEmpty else {
            return nil
        }

        return "http://" + value
    }
}
