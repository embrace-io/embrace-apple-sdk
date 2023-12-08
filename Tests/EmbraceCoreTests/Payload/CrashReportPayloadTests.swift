//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import XCTest
@testable import EmbraceCore
import EmbraceCommon
import TestSupport

// swiftlint:disable force_try force_cast

class CrashReportPayloadTests: XCTestCase {

    var dummyCrashReport: CrashReport {
        return CrashReport(
            ksCrashId: 123,
            sessionId: TestConstants.sessionId,
            timestamp: Date(),
            dictionary: [:]
        )
    }

    func test_properties() {
        // given a crash report
        let crashReport = dummyCrashReport

        // when creating a payload
        let payload = CrashReportPayload(from: crashReport, resourceFetcher: MockResourceFetcher())

        // then the properties are correctly set
        XCTAssertEqual(payload.crashPayload.id, crashReport.id.uuidString)

        let actual = NSDictionary(dictionary: payload.crashPayload.json)
        let expected = NSDictionary(dictionary: crashReport.dictionary)
        XCTAssertEqual(actual, expected)
    }

    func test_highLevelKeys() {
        // given a crash report
        let crashReport = dummyCrashReport

        // when serializing
        let payload = CrashReportPayload(from: crashReport, resourceFetcher: MockResourceFetcher())
        let data = try! JSONEncoder().encode(payload)
        let json = try! JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]

        // then the payload has all the necessary high level keys
        XCTAssertNotNil(json["a"])
        XCTAssertNotNil(json["d"])
        XCTAssertNotNil(json["u"])
        XCTAssertNotNil(json["cr"])
    }

    func test_crashKeys() {
        // given a crash report
        let crashReport = dummyCrashReport

        // when serializing
        let payload = CrashReportPayload(from: crashReport, resourceFetcher: MockResourceFetcher())
        let data = try! JSONEncoder().encode(payload)
        let json = try! JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]

        // then the crash payload contains the necessary keys
        let crash = json["cr"] as! [String: Any]
        XCTAssertEqual(crash["id"] as! String, crashReport.id.uuidString)
        XCTAssertNotNil(crash["ks"])

        let actual = NSDictionary(dictionary: crash["ks"] as! [String: Any])
        let expected = NSDictionary(dictionary: crashReport.dictionary)
        XCTAssertEqual(actual, expected)
    }
}

// swiftlint:enable force_try force_cast
