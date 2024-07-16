//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceStorageInternal
import EmbraceObjCUtilsInternal

struct ResourcePayload: Codable {
    var jailbroken: Bool?
    var diskTotalCapacity: Int?
    var osVersion: String?
    var osBuild: String?
    var osName: String?
    var osType: String?
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
    var processIdentifier: String?

    enum CodingKeys: String, CodingKey, CaseIterable {
        case jailbroken
        case environment
        case diskTotalCapacity = "disk_total_capacity"
        case osVersion = "os_version"
        case osBuild = "os_build"
        case osName = "os_name"
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
        case processIdentifier = "process_identifier"
    }

    init(from resources: [MetadataRecord]) {

        // bundle_id is constant and won't change over app install lifetime
        self.appBundleId = Bundle.main.bundleIdentifier

        resources.forEach { resource in
            if let key = AppResourceKey(rawValue: resource.key) {
                switch key {
                case .bundleVersion:
                    self.bundleVersion = resource.stringValue
                case .environment:
                    self.environment = resource.stringValue
                case .detailedEnvironment:
                    self.environmentDetail = resource.stringValue
                case .framework:
                    self.appFramework = resource.integerValue
                case .launchCount:
                    self.launchCount = resource.integerValue
                case .sdkVersion:
                    self.sdkVersion = resource.stringValue
                case .appVersion:
                    self.appVersion = resource.stringValue
                case .processIdentifier:
                    self.processIdentifier = resource.stringValue
                case .buildID:
                    self.buildId = resource.stringValue
                }
            }

            if let key = DeviceResourceKey(rawValue: resource.key) {
                switch key {
                case .isJailbroken:
                    self.jailbroken = resource.boolValue
                case .totalDiskSpace:
                    self.diskTotalCapacity = resource.integerValue
                case .architecture:
                    self.deviceArchitecture = resource.stringValue
                case .model:
                    self.deviceModel = resource.stringValue
                case .manufacturer:
                    self.deviceManufacturer = resource.stringValue
                case .screenResolution:
                    self.screenResolution = resource.stringValue
                case .osVersion:
                    self.osVersion = resource.stringValue
                case .osBuild:
                    self.osBuild = resource.stringValue
                case .osType:
                    self.osType = resource.stringValue
                case .osName:
                    self.osName = resource.stringValue
                case .osVariant:
                    self.osAlternateType = resource.stringValue
                case .locale, .timezone, .osDescription:
                    // This is part of the Metadata
                    break
                }
            }
        }
    }
}
