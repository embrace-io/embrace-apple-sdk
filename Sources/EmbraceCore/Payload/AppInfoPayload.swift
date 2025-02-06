//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceStorageInternal
import EmbraceCommonInternal
import EmbraceObjCUtilsInternal

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

    init (with resources: [MetadataRecord]) {
        self.appBundleId = Bundle.main.bundleIdentifier

        resources.forEach { resource in
            guard let key: AppResourceKey = AppResourceKey(rawValue: resource.key) else {
                return
            }

            switch key {
            case .bundleVersion:
                self.bundleVersion = resource.stringValue
            case .environment:
                self.environment = resource.stringValue
            case .detailedEnvironment:
                self.detailedEnvironment = resource.stringValue
            case .framework:
                self.framework = resource.integerValue
            case .launchCount:
                self.launchCount = resource.integerValue
            case .sdkVersion:
                self.sdkVersion = resource.stringValue
            case .appVersion:
                self.appVersion = resource.stringValue
            case .buildID:
                self.buildID = resource.stringValue
            default: break
            }
        }
    }
}
