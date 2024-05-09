//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import EmbraceStorage

@testable import EmbraceCore

class MetadataPayloadTests: XCTestCase {
    func test_encodeToJSONProperly() throws {
        let payloadStruct = MetadataPayload(from: [
            // User Resources
            MetadataRecord.userMetadata(key: UserResourceKey.email.rawValue, value: "email@domain.com"),
            MetadataRecord.userMetadata(key: UserResourceKey.identifier.rawValue, value: "12345"),
            MetadataRecord.userMetadata(key: UserResourceKey.name.rawValue, value: "embrace_user"),

            // Device Resources
            MetadataRecord.createResourceRecord(key: DeviceResourceKey.locale.rawValue, value: "en_US_POSIX"),
            MetadataRecord.createResourceRecord(key: DeviceResourceKey.timezone.rawValue, value: "GMT-3:00"),

            // Random properties
            MetadataRecord.userMetadata(key: "random_user_metadata_property", value: "value"),
            MetadataRecord.createResourceRecord(key: "random_resource_property", value: "value")
        ])

        let jsonData = try JSONEncoder().encode(payloadStruct)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any])

        XCTAssertEqual(json["locale"] as? String, "en_US_POSIX")
        XCTAssertEqual(json["username"] as? String, "embrace_user")
        XCTAssertEqual(json["email"] as? String, "email@domain.com")
        XCTAssertEqual(json["timezone_description"] as? String, "GMT-3:00")
        XCTAssertEqual(json["user_id"] as? String, "12345")
        XCTAssertEqual(json["personas"] as? [String], [])

        XCTAssertNil(json["random_user_metadata_property"])
        XCTAssertNil(json["random_resource_property"])
    }
}
