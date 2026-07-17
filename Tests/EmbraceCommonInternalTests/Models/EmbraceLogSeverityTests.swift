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
        XCTAssertEqual(EmbraceLogSeverity.info.name, "INFO")
        XCTAssertEqual(EmbraceLogSeverity.warn.name, "WARN")
        XCTAssertEqual(EmbraceLogSeverity.error.name, "ERROR")
    }

    func test_number_isRawValue() {
        XCTAssertEqual(EmbraceLogSeverity.info.rawValue, EmbraceLogSeverity.info.rawValue)
        XCTAssertEqual(EmbraceLogSeverity.warn.rawValue, EmbraceLogSeverity.warn.rawValue)
        XCTAssertEqual(EmbraceLogSeverity.error.rawValue, EmbraceLogSeverity.error.rawValue)
    }

    func test_description_isText() {
        XCTAssertEqual(EmbraceLogSeverity.info.name, EmbraceLogSeverity.info.description)
        XCTAssertEqual(EmbraceLogSeverity.warn.name, EmbraceLogSeverity.warn.description)
        XCTAssertEqual(EmbraceLogSeverity.error.name, EmbraceLogSeverity.error.description)
    }
}
