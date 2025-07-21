//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceStorageInternal
import TestSupport
import XCTest

@testable import EmbraceCore

class MetadataPayloadTests: XCTestCase {
    func test_encodeToJSONProperly() throws {
        let payloadStruct = MetadataPayload(from: [
            // wser Resources
            MockMetadata.createUserMetadata(key: UserResourceKey.email.rawValue, value: "email@domain.com"),
            MockMetadata.createUserMetadata(key: UserResourceKey.identifier.rawValue, value: "12345"),
            MockMetadata.createUserMetadata(key: UserResourceKey.name.rawValue, value: "embrace_user"),

            // device Resources
            MockMetadata.createResourceRecord(key: DeviceResourceKey.locale.rawValue, value: "en_US_POSIX"),
            MockMetadata.createResourceRecord(key: DeviceResourceKey.timezone.rawValue, value: "GMT-3:00"),

            // random properties
            MockMetadata.createUserMetadata(key: "random_user_metadata_property", value: "value"),
            MockMetadata.createResourceRecord(key: "random_resource_property", value: "value"),

            // persona tags
            MockMetadata.createPersonaTagRecord(value: "tag1"),
            MockMetadata.createPersonaTagRecord(value: "tag2")
        ])

        let jsonData = try JSONEncoder().encode(payloadStruct)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any])

        XCTAssertEqual(json["locale"] as? String, "en_US_POSIX")
        XCTAssertEqual(json["username"] as? String, "embrace_user")
        XCTAssertEqual(json["email"] as? String, "email@domain.com")
        XCTAssertEqual(json["timezone_description"] as? String, "GMT-3:00")
        XCTAssertEqual(json["user_id"] as? String, "12345")
        XCTAssertEqual(json["personas"] as? [String], ["tag1", "tag2"])

        XCTAssertNil(json["random_user_metadata_property"])
        XCTAssertNil(json["random_resource_property"])
    }
}
