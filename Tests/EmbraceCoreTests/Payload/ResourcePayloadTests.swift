//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import EmbraceStorage

@testable import EmbraceCore

class ResourcePayloadTests: XCTestCase {
    func test_encodeToJSONProperly() throws {
        let payloadStruct = ResourcePayload(from: [
            // App Resources that should be
            MetadataRecord.userMetadata(key: "emb.app.bundle_version", value: "9.8.7"),
            MetadataRecord.userMetadata(key: "emb.app.environment", value: "dev"),
            MetadataRecord.userMetadata(key: "emb.app.environment_detailed", value: "si"),
            MetadataRecord.userMetadata(key: "emb.app.framework", value: "111"),
            MetadataRecord.userMetadata(key: "emb.app.launch_count", value: "123"),
            MetadataRecord.userMetadata(key: "emb.app.version", value: "1.2.3"),
            MetadataRecord.userMetadata(key: "emb.sdk.version", value: "3.2.1"),

            // Device Resources that should be
            MetadataRecord.createResourceRecord(key: "emb.device.is_jailbroken", value: "true"),
            MetadataRecord.createResourceRecord(key: "emb.device.disk_size", value: "494384795648"),
            MetadataRecord.createResourceRecord(key: "emb.device.architecture", value: "arm64"),
            MetadataRecord.createResourceRecord(key: "emb.device.model.identifier", value: "arm64_model"),
            MetadataRecord.createResourceRecord(key: "emb.device.manufacturer", value: "Apple"),
            MetadataRecord.createResourceRecord(key: "emb.device.screenResolution", value: "1179x2556"),
            MetadataRecord.createResourceRecord(key: "emb.os.version", value: "17.0.1"),
            MetadataRecord.createResourceRecord(key: "emb.os.build_id", value: "23D60"),
            MetadataRecord.createResourceRecord(key: "emb.os.type", value: "iOS"),
            MetadataRecord.createResourceRecord(key: "emb.os.variant", value: "iOS_variant"),

            // Random properties that shouldn't be used
            MetadataRecord.userMetadata(key: "random_user_metadata_property", value: "value"),
            MetadataRecord.createResourceRecord(key: "emb.device.locale", value: "en_US_POSIX"),
            MetadataRecord.createResourceRecord(key: "emb.device.timezone", value: "GMT-3:00"),
            MetadataRecord.createResourceRecord(key: "random_resource_property", value: "value")
        ])

        let jsonData = try JSONEncoder().encode(payloadStruct)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any])

        XCTAssertEqual(json["bundle_version"] as? String, "9.8.7")
        XCTAssertEqual(json["environment"] as? String, "dev")
        XCTAssertEqual(json["environment_detail"] as? String, "si")
        XCTAssertEqual(json["app_framework"] as? Int, 111)
        XCTAssertEqual(json["launch_count"] as? Int, 123)
        XCTAssertEqual(json["sdk_version"] as? String, "3.2.1")
        XCTAssertEqual(json["app_version"] as? String, "1.2.3")

        XCTAssertEqual(json["jailbroken"] as? Bool, true)
        XCTAssertEqual(json["disk_total_capacity"] as? Int, 494384795648)
        XCTAssertEqual(json["device_architecture"] as? String, "arm64")
        XCTAssertEqual(json["device_model"] as? String, "arm64_model")
        XCTAssertEqual(json["device_manufacturer"] as? String, "Apple")
        XCTAssertEqual(json["screen_resolution"] as? String, "1179x2556")
        XCTAssertEqual(json["os_version"] as? String, "17.0.1")
        XCTAssertEqual(json["os_build"] as? String, "23D60")
        XCTAssertEqual(json["os_type"] as? String, "iOS")
        XCTAssertEqual(json["os_alternate_type"] as? String, "iOS_variant")

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
