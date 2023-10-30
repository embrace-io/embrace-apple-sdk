//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceIO
@testable import EmbraceStorage

// swiftlint:disable force_try force_cast

final class SessionPayloadTests: XCTestCase {

    var mockSessionRecord: SessionRecord {
        .init(id: "1234", state: .foreground, processId: UUID(), startTime: Date(timeIntervalSince1970: 10), endTime: Date(timeIntervalSince1970: 40))
    }

    func test_properties() {
        // given a session record
        let sessionRecord = mockSessionRecord

        // when creating a payload
        let payload = SessionPayload(from: sessionRecord)

        // then the properties are correctly set
        XCTAssertEqual(payload.messageFormatVersion, 15)
        XCTAssertEqual(payload.sessionInfo.sessionId, sessionRecord.id)
        XCTAssertEqual(payload.sessionInfo.startTime, sessionRecord.startTime.millisecondsSince1970Truncated)
        XCTAssertEqual(payload.sessionInfo.endTime, sessionRecord.endTime?.millisecondsSince1970Truncated)
        XCTAssertEqual(payload.sessionInfo.appState, sessionRecord.state)
    }

    func test_highLevelKeys() throws {
        // given a session record
        let sessionRecord = mockSessionRecord

        // when serializing
        let payload = SessionPayload(from: sessionRecord)
        let data = try! JSONEncoder().encode(payload)
        let json = try! JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]

        // then the payload has all the necessary high level keys
        XCTAssertNotNil(json["v"])
        XCTAssertEqual(json["v"] as! Int, 15)
        XCTAssertNotNil(json["s"])
        XCTAssertNotNil(json["a"])
        XCTAssertNotNil(json["d"])
        XCTAssertNotNil(json["u"])
        XCTAssertNotNil(json["spans"])
    }

    func test_sessionInfoKeys() throws {
        // given a session record
        let sessionRecord = mockSessionRecord

        // when serializing
        let payload = SessionPayload(from: sessionRecord)
        let data = try! JSONEncoder().encode(payload)
        let json = try! JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]

        // then the session payload contains the necessary keys
        let sessionInfo = json["s"] as! [String: Any]
        XCTAssertEqual(sessionInfo["id"] as! String, sessionRecord.id)
        XCTAssertEqual(sessionInfo["st"] as! Int, sessionRecord.startTime.millisecondsSince1970Truncated)
        XCTAssertEqual(sessionInfo["et"] as? Int, sessionRecord.endTime?.millisecondsSince1970Truncated)
        XCTAssertEqual(sessionInfo["as"] as! String, sessionRecord.state)
    }
}

// swiftlint:enable force_try force_cast
