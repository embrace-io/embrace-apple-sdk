//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceCore
@testable import OpenTelemetrySdk

final class WhitespaceSpanNameValidatorTests: XCTestCase {

    func spanData(named name: String) -> SpanData {
        return SpanData(
            traceId: .random(),
            spanId: .random(),
            name: name,
            kind: .internal,
            startTime: Date(),
            endTime: Date()
        )
    }

    func test_validate_isValid_ifNameContainsNonWhitespace() throws {
        var invalidEmpty = spanData(named: "")
        var invalidWhitespace = spanData(named: "  ")
        var invalidWhitespaceControl = spanData(named: "\t\n")

        var validNoWhitespace = spanData(named: "a")
        var validWithWhitespace = spanData(named: String(repeating: "a", count: 20))

        let validator = WhitespaceSpanNameValidator()

        XCTAssertFalse(validator.validate(data: &invalidEmpty))
        XCTAssertFalse(validator.validate(data: &invalidWhitespace))
        XCTAssertFalse(validator.validate(data: &invalidWhitespaceControl))
        XCTAssertTrue(validator.validate(data: &validNoWhitespace))
        XCTAssertTrue(validator.validate(data: &validWithWhitespace))
    }

}
