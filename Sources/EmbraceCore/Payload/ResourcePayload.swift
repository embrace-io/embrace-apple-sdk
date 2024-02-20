//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

struct ResourcePayload: Codable {
    var jailbroken: Bool?
    var diskTotalCapacity: Int?
    var osVersion: String?
    var osBuild: String?
    var osType: String? = "iOS"
    var osAlternateType: String?
    var deviceArchitecture: String?
    var deviceModel: String?
    var deviceManufacturer: String? = "Apple"
    var screenResolution: String?
    var buildId: String?
    var bundleVersion: String?
    var environment: String?
    var environmentDetail: String?
    var appFramework: Int?
    var launchCount: Int?
    var sdkVersion: String?
    var appVersion: String?
    var appBundleId: String?

    enum CodingKeys: String, CodingKey {
        case diskTotalCapacity = "disk_total_capacity"
        case osVersion = "os_version"
        case osBuild = "os_build"
        case osType = "os_type"
        case osAlternateType = "os_alternate_type"
        case deviceArchitecture = "device_architecture"
        case deviceModel = "device_model"
        case deviceManufacturer = "device_manufacturer"
        case screenResolution = "screen_resolution"
        case buildId = "build_id"
        case bundleVersion = "bundle_version"
        case environmentDetail = "environment_detail"
        case appFramework = "app_framework"
        case launchCount = "launch_count"
        case sdkVersion = "sdk_version"
        case appVersion = "app_version"
        case appBundleId = "app_bundle_id"
    }
}
