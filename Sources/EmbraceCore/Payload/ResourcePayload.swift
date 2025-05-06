//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceStorageInternal
@_implementationOnly import EmbraceObjCUtilsInternal
import EmbraceCommonInternal
#endif
import OpenTelemetrySdk

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
    var processStartTime: Int?
    var processPreWarm: Bool?
    var additionalResources: [String: String] = [:]

    private let excludedKeys: Set<String> = [
        DeviceResourceKey.locale.rawValue,
        DeviceResourceKey.timezone.rawValue,
        DeviceResourceKey.osDescription.rawValue,
        DeviceIdentifier.resourceKey,
        SessionPayloadBuilder.resourceName
    ]

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
        case bundleVersion = "build"
        case environmentDetail = "environment_detail"
        case appFramework = "app_framework"
        case launchCount = "launch_count"
        case sdkVersion = "sdk_version"
        case appVersion = "app_version"
        case appBundleId = "app_bundle_id"
        case processIdentifier = "process_identifier"
        case processStartTime = "process_start_time"
        case processPreWarm = "process_pre_warm"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(jailbroken, forKey: .jailbroken)
        try container.encode(diskTotalCapacity, forKey: .diskTotalCapacity)
        try container.encode(osVersion, forKey: .osVersion)
        try container.encode(osBuild, forKey: .osBuild)
        try container.encode(osName, forKey: .osName)
        try container.encode(osType, forKey: .osType)
        try container.encode(osAlternateType, forKey: .osAlternateType)
        try container.encode(deviceArchitecture, forKey: .deviceArchitecture)
        try container.encode(deviceModel, forKey: .deviceModel)
        try container.encode(deviceManufacturer, forKey: .deviceManufacturer)
        try container.encode(screenResolution, forKey: .screenResolution)
        try container.encode(buildId, forKey: .buildId)
        try container.encode(bundleVersion, forKey: .bundleVersion)
        try container.encode(environment, forKey: .environment)
        try container.encode(environmentDetail, forKey: .environmentDetail)
        try container.encode(appFramework, forKey: .appFramework)
        try container.encode(launchCount, forKey: .launchCount)
        try container.encode(sdkVersion, forKey: .sdkVersion)
        try container.encode(appVersion, forKey: .appVersion)
        try container.encode(appBundleId, forKey: .appBundleId)
        try container.encode(processIdentifier, forKey: .processIdentifier)
        try container.encode(processStartTime, forKey: .processStartTime)
        try container.encode(processPreWarm, forKey: .processPreWarm)

        var additionalResourcesContainer = encoder.container(keyedBy: StringDictionaryCodingKeys.self)
        for (key, value) in additionalResources {
            if let codingKey = StringDictionaryCodingKeys(stringValue: key) {
                try additionalResourcesContainer.encode(value, forKey: codingKey)
            }
        }
    }

    init(from resources: [EmbraceMetadata]) {

        // bundle_id is constant and won't change over app install lifetime
        self.appBundleId = Bundle.main.bundleIdentifier

        resources.forEach { resource in
            guard !excludedKeys.contains(resource.key) else {
                return
            }

            if let key = AppResourceKey(rawValue: resource.key) {
                switch key {
                case .bundleVersion:
                    self.bundleVersion = resource.value
                case .environment:
                    self.environment = resource.value
                case .detailedEnvironment:
                    self.environmentDetail = resource.value
                case .framework:
                    self.appFramework = Int(resource.value)
                case .launchCount:
                    self.launchCount = Int(resource.value)
                case .sdkVersion:
                    self.sdkVersion = resource.value
                case .appVersion:
                    self.appVersion = resource.value
                case .processIdentifier:
                    self.processIdentifier = resource.value
                case .buildID:
                    self.buildId = resource.value
                case .processStartTime:
                    self.processStartTime = Int(resource.value)
                case .processPreWarm:
                    self.processPreWarm = Bool(resource.value)
                }

            } else if let key = DeviceResourceKey(rawValue: resource.key) {
                switch key {
                case .isJailbroken:
                    self.jailbroken = Bool(resource.value)
                case .totalDiskSpace:
                    self.diskTotalCapacity = Int(resource.value)
                case .architecture:
                    self.deviceArchitecture = resource.value
                case .screenResolution:
                    self.screenResolution = resource.value
                case .osBuild:
                    self.osBuild = resource.value
                case .osVariant:
                    self.osAlternateType = resource.value
                default:
                    break
                }
            } else if let key = ResourceAttributes(rawValue: resource.key) {
                switch key {
                case .deviceModelIdentifier:
                    self.deviceModel = resource.value
                case .deviceManufacturer:
                    self.deviceManufacturer = resource.value
                case .osVersion:
                    self.osVersion = resource.value
                case .osType:
                    self.osType = resource.value
                case .osName:
                    self.osName = resource.value
                default:
                    break
                }
            } else {
                self.additionalResources[resource.key] = resource.value
            }
        }
    }
}

extension ResourcePayload {
    struct StringDictionaryCodingKeys: CodingKey {
        var stringValue: String
        init?(stringValue: String) {
            self.stringValue = stringValue
        }

        // We don't use integer values, so we set this to nil just in case.
        var intValue: Int?
        init?(intValue: Int) {
            return nil
        }
    }
}
