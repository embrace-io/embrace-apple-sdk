//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceCommon

/// Many tests in this class might seem trivial, and indeed, they are.
/// However, the `LogSeverity` class serves as a bridge to the `Severity` concept from OTel.
/// Should there be any changes (such as the integers associated with each case), these tests
/// are designed to alert you, requiring a review or update to ensure consistency.
///
/// In case new `LogSeverity` cases are added *please add them to this tests*
class LogSeverityTests: XCTestCase {
    func test_ensureIdentifiersAreCorrectAndConsistentWithOTel() {
        XCTAssertEqual(LogSeverity.info.rawValue, 9)
        XCTAssertEqual(LogSeverity.warn.rawValue, 13)
        XCTAssertEqual(LogSeverity.error.rawValue, 17)
    }

    func test_ensureTextValuesAreCorrectAndConsistentWithOTel() {
        XCTAssertEqual(LogSeverity.info.text, "INFO")
        XCTAssertEqual(LogSeverity.warn.text, "WARN")
        XCTAssertEqual(LogSeverity.error.text, "ERROR")
    }

    func test_number_isRawValue() {
        XCTAssertEqual(LogSeverity.info.rawValue, LogSeverity.info.number)
        XCTAssertEqual(LogSeverity.warn.rawValue, LogSeverity.warn.number)
        XCTAssertEqual(LogSeverity.error.rawValue, LogSeverity.error.number)
    }

    func test_description_isText() {
        XCTAssertEqual(LogSeverity.info.text, LogSeverity.info.description)
        XCTAssertEqual(LogSeverity.warn.text, LogSeverity.warn.description)
        XCTAssertEqual(LogSeverity.error.text, LogSeverity.error.description)
    }
}
