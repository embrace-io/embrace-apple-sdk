//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import UIKit
@testable import EmbraceIO
@testable import EmbraceStorage

final class PayloadBuilderTests: XCTestCase {
    func testSessionPayload() {
        // Given
        let options = EmbraceOptions(appId: "12345", platform: .iOS)!
        let payloadBuilder = PayloadBuilder(with: options)
        let sessionRecord = PayloadBuilderTests.mockSessionRecord

        // Then
        if let result = payloadBuilder.prepareSessionPayload(from: sessionRecord) {
            if let dictionary = try? JSONSerialization.jsonObject(with: result) as? [String: Any] {
                XCTAssertEqual(dictionary.keys.count, 6)
                XCTAssertNotNil(dictionary["v"])
                XCTAssertNotNil(dictionary["s"])
                XCTAssertNotNil(dictionary["a"])
                XCTAssertNotNil(dictionary["d"])
                XCTAssertNotNil(dictionary["u"])
                XCTAssertNotNil(dictionary["spans"])
            } else {
                XCTFail("\(#function): Failed to serialize encoded session payload")
            }
        } else {
            XCTFail("\(#function): Failed to encode session payload")
        }
    }

    func testSessionInfoPayload() {
        // Given
        let sessionInfo = SessionInfoPayload(from: PayloadBuilderTests.mockSessionRecord)
        let expected = PayloadBuilderTests.mockSessionInfoDictionary

        // Then
        if let encodedSessionInfo = try? JSONEncoder().encode(sessionInfo) {
            if let dictionary = try? JSONSerialization.jsonObject(with: encodedSessionInfo) as? [String: Any] {
                XCTAssertEqual(dictionary.keys.count, 4)
                XCTAssertEqual(dictionary["id"] as? String, expected["id"] as? String)
                XCTAssertEqual(dictionary["st"] as? Int, expected["st"] as? Int)
                XCTAssertEqual(dictionary["et"] as? Int, expected["et"] as? Int)
                XCTAssertEqual(dictionary["as"] as? String, expected["as"] as? String)
            } else {
                XCTFail("\(#function): Failed to serialize encoded Session Info Payload")
            }
        } else {
            XCTFail("\(#function): Failed to encode Session Info Payload")
        }
    }
}

extension PayloadBuilderTests {
    static var mockSessionRecord: SessionRecord {
        .init(id: "1234", state: .foreground, startTime: Date(timeIntervalSince1970: 10), endTime: Date(timeIntervalSince1970: 40))
    }

    static var mockSessionInfoDictionary: [String: Any] {
        ["id": "1234",
         "st": mockSessionRecord.startTime.millisecondsSince1970Truncated,
         "et": mockSessionRecord.endTime!.millisecondsSince1970Truncated,
         "as": "foreground"]
    }
}
