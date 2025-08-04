//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceStorageInternal
    import EmbraceCommonInternal
    import EmbraceObjCUtilsInternal
#endif

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

    init(with resources: [EmbraceMetadata]) {
        self.appBundleId = Bundle.main.bundleIdentifier

        resources.forEach { resource in
            guard let key: AppResourceKey = AppResourceKey(rawValue: resource.key) else {
                return
            }

            switch key {
            case .bundleVersion:
                self.bundleVersion = resource.value
            case .environment:
                self.environment = resource.value
            case .detailedEnvironment:
                self.detailedEnvironment = resource.value
            case .framework:
                self.framework = Int(resource.value)
            case .launchCount:
                self.launchCount = Int(resource.value)
            case .sdkVersion:
                self.sdkVersion = resource.value
            case .appVersion:
                self.appVersion = resource.value
            case .buildID:
                self.buildID = resource.value
            default: break
            }
        }
    }
}
