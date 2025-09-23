//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceObjCUtilsInternal
import EmbraceStorageInternal
import OpenTelemetryApi
import OpenTelemetrySdk
import TestSupport
import XCTest

@testable import EmbraceCore

class ResourcePayloadTests: XCTestCase {
    func test_encodeToJSONProperly() throws {
        let payloadStruct = ResourcePayload(from: [
            // App Resources that should be present
            MockMetadata.createUserMetadata(key: AppResourceKey.bundleVersion.rawValue, value: "9.8.7"),
            MockMetadata.createUserMetadata(key: AppResourceKey.environment.rawValue, value: "dev"),
            MockMetadata.createUserMetadata(key: AppResourceKey.detailedEnvironment.rawValue, value: "si"),
            MockMetadata.createUserMetadata(key: AppResourceKey.framework.rawValue, value: "111"),
            MockMetadata.createUserMetadata(key: AppResourceKey.launchCount.rawValue, value: "123"),
            MockMetadata.createUserMetadata(key: AppResourceKey.appVersion.rawValue, value: "1.2.3"),
            MockMetadata.createUserMetadata(key: AppResourceKey.sdkVersion.rawValue, value: "3.2.1"),
            MockMetadata.createUserMetadata(key: AppResourceKey.processIdentifier.rawValue, value: "12345"),
            MockMetadata.createUserMetadata(key: AppResourceKey.buildID.rawValue, value: "fakebuilduuidnohyphen"),
            MockMetadata.createUserMetadata(key: AppResourceKey.processStartTime.rawValue, value: "12345"),
            MockMetadata.createUserMetadata(key: AppResourceKey.processPreWarm.rawValue, value: "true"),

            // Device Resources that should be present
            MockMetadata.createResourceRecord(key: DeviceResourceKey.isJailbroken.rawValue, value: "true"),
            MockMetadata.createResourceRecord(key: DeviceResourceKey.totalDiskSpace.rawValue, value: "494384795648"),
            MockMetadata.createResourceRecord(key: DeviceResourceKey.architecture.rawValue, value: "arm64"),
            MockMetadata.createResourceRecord(
                key: SemanticConventions.Device.modelIdentifier.rawValue, value: "arm64_model"),
            MockMetadata.createResourceRecord(key: SemanticConventions.Device.manufacturer.rawValue, value: "Apple"),
            MockMetadata.createResourceRecord(key: DeviceResourceKey.screenResolution.rawValue, value: "1179x2556"),
            MockMetadata.createResourceRecord(key: SemanticConventions.Os.version.rawValue, value: "17.0.1"),
            MockMetadata.createResourceRecord(key: DeviceResourceKey.osBuild.rawValue, value: "23D60"),
            MockMetadata.createResourceRecord(key: SemanticConventions.Os.type.rawValue, value: "darwin"),
            MockMetadata.createResourceRecord(key: DeviceResourceKey.osVariant.rawValue, value: "iOS_variant"),
            MockMetadata.createResourceRecord(key: DeviceResourceKey.locale.rawValue, value: "en_US_POSIX"),
            MockMetadata.createResourceRecord(key: DeviceResourceKey.timezone.rawValue, value: "GMT-3:00"),

            // session counter
            MockMetadata.createResourceRecord(key: SessionPayloadBuilder.resourceName, value: "10"),

            // Random properties that should be used
            MockMetadata.createUserMetadata(key: "random_user_metadata_property", value: "value1"),
            MockMetadata.createResourceRecord(key: "random_resource_property", value: "value2")
        ])

        let jsonData = try JSONEncoder().encode(payloadStruct)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any])

        XCTAssertEqual(json["app_bundle_id"] as? String, Bundle.main.bundleIdentifier)
        XCTAssertEqual(json["build_id"] as? String, "fakebuilduuidnohyphen")

        XCTAssertEqual(json["build"] as? String, "9.8.7")
        XCTAssertEqual(json["environment"] as? String, "dev")
        XCTAssertEqual(json["environment_detail"] as? String, "si")
        XCTAssertEqual(json["app_framework"] as? Int, 111)
        XCTAssertEqual(json["launch_count"] as? Int, 123)
        XCTAssertEqual(json["sdk_version"] as? String, "3.2.1")
        XCTAssertEqual(json["app_version"] as? String, "1.2.3")
        XCTAssertEqual(json["process_identifier"] as? String, "12345")
        XCTAssertEqual(json["process_start_time"] as? Int, 12345)
        XCTAssertEqual(json["process_pre_warm"] as? Bool, true)

        XCTAssertEqual(json["jailbroken"] as? Bool, true)
        XCTAssertEqual(json["disk_total_capacity"] as? Int, 494_384_795_648)
        XCTAssertEqual(json["device_architecture"] as? String, "arm64")
        XCTAssertEqual(json["device_model"] as? String, "arm64_model")
        XCTAssertEqual(json["device_manufacturer"] as? String, "Apple")
        XCTAssertEqual(json["screen_resolution"] as? String, "1179x2556")
        XCTAssertEqual(json["os_version"] as? String, "17.0.1")
        XCTAssertEqual(json["os_build"] as? String, "23D60")
        XCTAssertEqual(json["os_type"] as? String, "darwin")
        XCTAssertEqual(json["os_alternate_type"] as? String, "iOS_variant")
        XCTAssertEqual(json["os_name"] as? String, "ios")
        XCTAssertEqual(json["sdk_platform"] as? String, "ios")

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
        XCTAssertEqual(json["os_name"] as? String, "ios")
        XCTAssertEqual(json["sdk_platform"] as? String, "ios")
    }
}
