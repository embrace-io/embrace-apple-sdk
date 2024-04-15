//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import EmbraceStorage

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

            // Device Resources that should be present
            MetadataRecord.createResourceRecord(key: DeviceResourceKey.isJailbroken.rawValue, value: "true"),
            MetadataRecord.createResourceRecord(key: DeviceResourceKey.totalDiskSpace.rawValue, value: "494384795648"),
            MetadataRecord.createResourceRecord(key: DeviceResourceKey.architecture.rawValue, value: "arm64"),
            MetadataRecord.createResourceRecord(key: DeviceResourceKey.model.rawValue, value: "arm64_model"),
            MetadataRecord.createResourceRecord(key: DeviceResourceKey.manufacturer.rawValue, value: "Apple"),
            MetadataRecord.createResourceRecord(key: DeviceResourceKey.screenResolution.rawValue, value: "1179x2556"),
            MetadataRecord.createResourceRecord(key: DeviceResourceKey.osVersion.rawValue, value: "17.0.1"),
            MetadataRecord.createResourceRecord(key: DeviceResourceKey.osBuild.rawValue, value: "23D60"),
            MetadataRecord.createResourceRecord(key: DeviceResourceKey.osType.rawValue, value: "darwin"),
            MetadataRecord.createResourceRecord(key: DeviceResourceKey.osVariant.rawValue, value: "iOS_variant"),
            MetadataRecord.createResourceRecord(key: DeviceResourceKey.osName.rawValue, value: "iPadOS"),
            MetadataRecord.createResourceRecord(key: DeviceResourceKey.locale.rawValue, value: "en_US_POSIX"),
            MetadataRecord.createResourceRecord(key: DeviceResourceKey.timezone.rawValue, value: "GMT-3:00"),

            // Random properties that shouldn't be used
            MetadataRecord.userMetadata(key: "random_user_metadata_property", value: "value"),
            MetadataRecord.createResourceRecord(key: "random_resource_property", value: "value")
        ])

        let jsonData = try JSONEncoder().encode(payloadStruct)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any])

        XCTAssertEqual(json["app_bundle_id"] as? String, Bundle.main.bundleIdentifier)
        XCTAssertNotNil(json["build_id"] as? String)

        XCTAssertEqual(json["bundle_version"] as? String, "9.8.7")
        XCTAssertEqual(json["environment"] as? String, "dev")
        XCTAssertEqual(json["environment_detail"] as? String, "si")
        XCTAssertEqual(json["app_framework"] as? Int, 111)
        XCTAssertEqual(json["launch_count"] as? Int, 123)
        XCTAssertEqual(json["sdk_version"] as? String, "3.2.1")
        XCTAssertEqual(json["app_version"] as? String, "1.2.3")
        XCTAssertEqual(json["process_identifier"] as? String, "12345")

        XCTAssertEqual(json["jailbroken"] as? Bool, true)
        XCTAssertEqual(json["disk_total_capacity"] as? Int, 494384795648)
        XCTAssertEqual(json["device_architecture"] as? String, "arm64")
        XCTAssertEqual(json["device_model"] as? String, "arm64_model")
        XCTAssertEqual(json["device_manufacturer"] as? String, "Apple")
        XCTAssertEqual(json["screen_resolution"] as? String, "1179x2556")
        XCTAssertEqual(json["os_version"] as? String, "17.0.1")
        XCTAssertEqual(json["os_build"] as? String, "23D60")
        XCTAssertEqual(json["os_type"] as? String, "darwin")
        XCTAssertEqual(json["os_alternate_type"] as? String, "iOS_variant")
        XCTAssertEqual(json["os_name"] as? String, "iPadOS")

        let jsonKeys = Set(json.keys)
        let expectedKeys = Set(ResourcePayload.CodingKeys.allCases.map { $0.rawValue })

        XCTAssertEqual(
            jsonKeys,
            expectedKeys,
            "Unexpected keys: \(jsonKeys.subtracting(expectedKeys)) Missing keys: \(expectedKeys.subtracting(jsonKeys))"
        )

        XCTAssertNil(json["random_user_metadata_property"])
        XCTAssertNil(json["random_resource_property"])
    }

    func test_encodeToJSON_alwaysHasBundleId() throws {
        let payloadStruct = ResourcePayload(from: [])

        let jsonData = try JSONEncoder().encode(payloadStruct)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any])

        XCTAssertEqual(json["app_bundle_id"] as? String, Bundle.main.bundleIdentifier!)
    }

    func test_encodeToJSON_alwaysHasBuildId() throws {
        let payloadStruct = ResourcePayload(from: [])

        let jsonData = try JSONEncoder().encode(payloadStruct)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any])

        XCTAssertNotNil(json["build_id"])
    }
}
