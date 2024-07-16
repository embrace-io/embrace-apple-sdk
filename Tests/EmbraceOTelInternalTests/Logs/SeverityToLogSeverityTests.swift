//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceOTelInternal

import EmbraceCommonInternal
import OpenTelemetryApi

class SeverityToLogSeverityTests: XCTestCase {
    func testSeverityInfo_toLogSeverity_shouldBeLogSeverityInfo() {
        XCTAssertEqual(LogSeverity.info, Severity.info.toLogSeverity())
    }

    func testSeverityInfo2to4_toLogSeverity_shouldBeNil() {
        XCTAssertNil(Severity.info2.toLogSeverity())
        XCTAssertNil(Severity.info3.toLogSeverity())
        XCTAssertNil(Severity.info4.toLogSeverity())
    }

    func testSeverityWarn_toLogSeverity_shouldBeLogSeverityWarn() {
        XCTAssertEqual(LogSeverity.warn, Severity.warn.toLogSeverity())
    }

    func testSeverityWarn2to4_toLogSeverity_shouldBeNil() {
        XCTAssertNil(Severity.warn2.toLogSeverity())
        XCTAssertNil(Severity.warn3.toLogSeverity())
        XCTAssertNil(Severity.warn4.toLogSeverity())
    }

    func testSeverityError_toLogSeverity_shouldBeLogSeverityError() {
        XCTAssertEqual(LogSeverity.error, Severity.error.toLogSeverity())
    }

    func testSeverityError2to4_toLogSeverity_shouldBeNil() {
        XCTAssertNil(Severity.error2.toLogSeverity())
        XCTAssertNil(Severity.error3.toLogSeverity())
        XCTAssertNil(Severity.error4.toLogSeverity())
    }
}
