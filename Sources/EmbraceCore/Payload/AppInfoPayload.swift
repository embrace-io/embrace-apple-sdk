//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceStorage
import EmbraceCommon

struct AppInfoPayload: Codable {
    var buildID: String?
    var bundleVersion: String?
    var environment: String?
    var detailedEnvironment: String?
    var framework: Int?
    var launchCount: Int?
    var sdkVersion: String?
    var appVersion: String?
    var appBundleId: String?

    enum CodingKeys: String, CodingKey {
        case buildID = "bi"
        case bundleVersion = "bv"
        case environment = "e"
        case detailedEnvironment = "ed"
        case framework = "f"
        case launchCount = "lc"
        case sdkVersion = "sdk"
        case appVersion = "v"
        case appBundleId = "bid"
    }

    init (with resources: [ResourceRecord]) {
        resources.forEach { resource in
            guard let key: AppResourceKeys = AppResourceKeys(rawValue: resource.key) else {
                return
            }

            let value = resource.value

            switch key {
            case .buildUUID:
                self.buildID = value
            case .bundleVersion:
                self.bundleVersion = value
            case .environment:
                self.environment = value
            case .detailedEnvironment:
                self.detailedEnvironment = value
            case .framework:
                self.framework = Int(value)
            case .launchCount:
                self.launchCount = Int(value)
            case .sdkVersion:
                self.sdkVersion = value
            case .appVersion:
                self.appVersion = value
            case .bundleId:
                self.appBundleId = value
            }
        }
    }
}
