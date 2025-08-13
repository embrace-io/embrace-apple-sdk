//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import OpenTelemetryApi
import XCTest
import EmbraceSemantics
@testable import EmbraceOTelInternal

class SeverityToLogSeverityTests: XCTestCase {
    func testSeverityInfo_toLogSeverity_shouldBeLogSeverityInfo() {
        XCTAssertEqual(EmbraceLogSeverity.info, Severity.info.toLogSeverity())
    }

    func testSeverityInfo2to4_toLogSeverity_shouldBeNil() {
        XCTAssertNil(Severity.info2.toLogSeverity())
        XCTAssertNil(Severity.info3.toLogSeverity())
        XCTAssertNil(Severity.info4.toLogSeverity())
    }

    func testSeverityWarn_toLogSeverity_shouldBeLogSeverityWarn() {
        XCTAssertEqual(EmbraceLogSeverity.warn, Severity.warn.toLogSeverity())
    }

    func testSeverityWarn2to4_toLogSeverity_shouldBeNil() {
        XCTAssertNil(Severity.warn2.toLogSeverity())
        XCTAssertNil(Severity.warn3.toLogSeverity())
        XCTAssertNil(Severity.warn4.toLogSeverity())
    }

    func testSeverityError_toLogSeverity_shouldBeLogSeverityError() {
        XCTAssertEqual(EmbraceLogSeverity.error, Severity.error.toLogSeverity())
    }

    func testSeverityError2to4_toLogSeverity_shouldBeNil() {
        XCTAssertNil(Severity.error2.toLogSeverity())
        XCTAssertNil(Severity.error3.toLogSeverity())
        XCTAssertNil(Severity.error4.toLogSeverity())
    }
}
