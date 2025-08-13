//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceSemantics

/// Many tests in this class might seem trivial, and indeed, they are.
/// However, the `LogSeverity` class serves as a bridge to the `Severity` concept from OTel.
/// Should there be any changes (such as the integers associated with each case), these tests
/// are designed to alert you, requiring a review or update to ensure consistency.
///
/// In case new `LogSeverity` cases are added *please add them to this tests*
class EmbraceLogSeverityTests: XCTestCase {
    func test_ensureIdentifiersAreCorrectAndConsistentWithOTel() {
        XCTAssertEqual(EmbraceLogSeverity.info.rawValue, 9)
        XCTAssertEqual(EmbraceLogSeverity.warn.rawValue, 13)
        XCTAssertEqual(EmbraceLogSeverity.error.rawValue, 17)
    }

    func test_ensureTextValuesAreCorrectAndConsistentWithOTel() {
        XCTAssertEqual(EmbraceLogSeverity.info.text, "INFO")
        XCTAssertEqual(EmbraceLogSeverity.warn.text, "WARN")
        XCTAssertEqual(EmbraceLogSeverity.error.text, "ERROR")
    }

    func test_number_isRawValue() {
        XCTAssertEqual(EmbraceLogSeverity.info.rawValue, EmbraceLogSeverity.info.number)
        XCTAssertEqual(EmbraceLogSeverity.warn.rawValue, EmbraceLogSeverity.warn.number)
        XCTAssertEqual(EmbraceLogSeverity.error.rawValue, EmbraceLogSeverity.error.number)
    }

    func test_description_isText() {
        XCTAssertEqual(EmbraceLogSeverity.info.text, EmbraceLogSeverity.info.description)
        XCTAssertEqual(EmbraceLogSeverity.warn.text, EmbraceLogSeverity.warn.description)
        XCTAssertEqual(EmbraceLogSeverity.error.text, EmbraceLogSeverity.error.description)
    }
}
