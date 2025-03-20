//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import EmbraceStorageInternal
import OpenTelemetrySdk
@testable import EmbraceCore

class ResourcePayloadTests: XCTestCase {
    func test_encodeToJSONProperly() throws {
        let payloadStruct = ResourcePayload(from: [
            // App Resources that should be present
            MetadataRecord.userMetadata(key: AppResourceKey.bundleVersion.rawValue, value: "9.8.7"),
            MetadataRecord.userMetadata(key: AppResourceKey.environment.rawValue, value: "dev"),
            MetadataRecord.userMetadata(key: AppResourceKey.detailedEnvironment.rawValue, value: "si"),
            MetadataRecord.userMetadata(key: AppResourceKey.framework.rawValue, value: "111"),
            MetadataRecord.userMetadata(key: AppResourceKey.launchCount.rawValue, value: "123"),
            MetadataRecord.userMetadata(key: AppResourceKey.appVersion.rawValue, value: "1.2.3"),
            MetadataRecord.userMetadata(key: AppResourceKey.sdkVersion.rawValue, value: "3.2.1"),
            MetadataRecord.userMetadata(key: AppResourceKey.processIdentifier.rawValue, value: "12345"),
            MetadataRecord.userMetadata(key: AppResourceKey.buildID.rawValue, value: "fakebuilduuidnohyphen"),
            MetadataRecord.userMetadata(key: AppResourceKey.processStartTime.rawValue, value: "12345"),
            MetadataRecord.userMetadata(key: AppResourceKey.processPreWarm.rawValue, value: "true"),

            // Device Resources that should be present
            MetadataRecord.createResourceRecord(key: DeviceResourceKey.isJailbroken.rawValue, value: "true"),
            MetadataRecord.createResourceRecord(key: DeviceResourceKey.totalDiskSpace.rawValue, value: "494384795648"),
            MetadataRecord.createResourceRecord(key: DeviceResourceKey.architecture.rawValue, value: "arm64"),
            MetadataRecord.createResourceRecord(key: ResourceAttributes.deviceModelIdentifier.rawValue, value: "arm64_model"),
            MetadataRecord.createResourceRecord(key: ResourceAttributes.deviceManufacturer.rawValue, value: "Apple"),
            MetadataRecord.createResourceRecord(key: DeviceResourceKey.screenResolution.rawValue, value: "1179x2556"),
            MetadataRecord.createResourceRecord(key: ResourceAttributes.osVersion.rawValue, value: "17.0.1"),
            MetadataRecord.createResourceRecord(key: DeviceResourceKey.osBuild.rawValue, value: "23D60"),
            MetadataRecord.createResourceRecord(key: ResourceAttributes.osType.rawValue, value: "darwin"),
            MetadataRecord.createResourceRecord(key: DeviceResourceKey.osVariant.rawValue, value: "iOS_variant"),
            MetadataRecord.createResourceRecord(key: ResourceAttributes.osName.rawValue, value: "iPadOS"),
            MetadataRecord.createResourceRecord(key: DeviceResourceKey.locale.rawValue, value: "en_US_POSIX"),
            MetadataRecord.createResourceRecord(key: DeviceResourceKey.timezone.rawValue, value: "GMT-3:00"),

            // session counter
            MetadataRecord.createResourceRecord(key: SessionPayloadBuilder.resourceName, value: "10"),

            // Random properties that should be used
            MetadataRecord.userMetadata(key: "random_user_metadata_property", value: "value1"),
            MetadataRecord.createResourceRecord(key: "random_resource_property", value: "value2")
        ])

        let jsonData = try JSONEncoder().encode(payloadStruct)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any])

        XCTAssertEqual(json[ResourcePayload.CodingKeys.appBundleId.rawValue] as? String, Bundle.main.bundleIdentifier)
        XCTAssertEqual(json[ResourcePayload.CodingKeys.buildId.rawValue] as? String, "fakebuilduuidnohyphen")

        XCTAssertEqual(json[ResourcePayload.CodingKeys.bundleVersion.rawValue] as? String, "9.8.7")
        XCTAssertEqual(json[ResourcePayload.CodingKeys.environment.rawValue] as? String, "dev")
        XCTAssertEqual(json[ResourcePayload.CodingKeys.environmentDetail.rawValue] as? String, "si")
        XCTAssertEqual(json[ResourcePayload.CodingKeys.appFramework.rawValue] as? Int, 111)
        XCTAssertEqual(json[ResourcePayload.CodingKeys.launchCount.rawValue] as? Int, 123)
        XCTAssertEqual(json[ResourcePayload.CodingKeys.sdkVersion.rawValue] as? String, "3.2.1")
        XCTAssertEqual(json[ResourcePayload.CodingKeys.appVersion.rawValue] as? String, "1.2.3")
        XCTAssertEqual(json[ResourcePayload.CodingKeys.processIdentifier.rawValue] as? String, "12345")
        XCTAssertEqual(json[ResourcePayload.CodingKeys.processStartTime.rawValue] as? Int, 12345)
        XCTAssertEqual(json[ResourcePayload.CodingKeys.processPreWarm.rawValue] as? Bool, true)

        XCTAssertEqual(json[ResourcePayload.CodingKeys.jailbroken.rawValue] as? Bool, true)
        XCTAssertEqual(json[ResourcePayload.CodingKeys.diskTotalCapacity.rawValue] as? Int, 494384795648)
        XCTAssertEqual(json[ResourcePayload.CodingKeys.deviceArchitecture.rawValue] as? String, "arm64")
        XCTAssertEqual(json[ResourcePayload.CodingKeys.deviceModel.rawValue] as? String, "arm64_model")
        XCTAssertEqual(json[ResourcePayload.CodingKeys.deviceManufacturer.rawValue] as? String, "Apple")
        XCTAssertEqual(json[ResourcePayload.CodingKeys.screenResolution.rawValue] as? String, "1179x2556")
        XCTAssertEqual(json[ResourcePayload.CodingKeys.osVersion.rawValue] as? String, "17.0.1")
        XCTAssertEqual(json[ResourcePayload.CodingKeys.osBuild.rawValue] as? String, "23D60")
        XCTAssertEqual(json[ResourcePayload.CodingKeys.osType.rawValue] as? String, "darwin")
        XCTAssertEqual(json[ResourcePayload.CodingKeys.osAlternateType.rawValue] as? String, "iOS_variant")
        XCTAssertEqual(json[ResourcePayload.CodingKeys.osName.rawValue] as? String, "iPadOS")

        let jsonKeys = Set(json.keys)
        let expectedKeys = Set(ResourcePayload.CodingKeys.allCases.map { $0.rawValue })
        XCTAssertTrue(jsonKeys.isSuperset(of: expectedKeys))
        XCTAssertEqual(json["random_user_metadata_property"] as? String, "value1")
        XCTAssertEqual(json["random_resource_property"] as? String, "value2")
    }

    func test_encodeToJSON_alwaysHasBundleId() throws {
        let payloadStruct = ResourcePayload(from: [])

        let jsonData = try JSONEncoder().encode(payloadStruct)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any])

        XCTAssertEqual(json["app_bundle_id"] as? String, Bundle.main.bundleIdentifier!)
    }
}
