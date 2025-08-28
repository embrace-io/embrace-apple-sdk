//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import XCTest
import EmbraceSemantics
@testable import EmbraceCore

class LogPayloadTests: XCTestCase {
    func test_encodeToJSONProperly() throws {
        let payloadStruct = LogPayload(
            timeUnixNano: "123456789",
            severityNumber: EmbraceLogSeverity.info.rawValue,
            severityText: EmbraceLogSeverity.info.name,
            body: "Hello World",
            attributes: [
                .init(key: "hello", value: "world")
            ]
        )

        let jsonData = try JSONEncoder().encode(payloadStruct)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any])

        XCTAssertEqual(json["time_unix_nano"] as? String, "123456789")
        XCTAssertEqual(json["severity_number"] as? Int, 9)
        XCTAssertEqual(json["severity_text"] as? String, "INFO")
        XCTAssertEqual(json["body"] as? String, "Hello World")
        let attributes = json["attributes"] as? [[String: Any]]
        XCTAssertEqual(attributes?[0]["key"] as? String, "hello")
        XCTAssertEqual(attributes?[0]["value"] as? String, "world")
    }
}
