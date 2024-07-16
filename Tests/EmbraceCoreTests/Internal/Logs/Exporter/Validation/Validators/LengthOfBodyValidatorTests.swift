//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceCore
import EmbraceOTelInternal

final class LengthOfBodyValidatorTests: XCTestCase {

    func logData(body: String?) -> ReadableLogRecord {
        return ReadableLogRecord(
            resource: .init(),
            instrumentationScopeInfo: .init(),
            timestamp: Date(),
            body: body,
            attributes: [:]
        )
    }

    func test_validate_init_defaultsToCorrect_allowedCharacterCount() {
        let validator = LengthOfBodyValidator()
        XCTAssertEqual(validator.allowedCharacterCount, 1...4000)
    }

    func test_validate_isInvalid_ifBodyIsNil() {
        let validator = LengthOfBodyValidator()

        var invalidNil = logData(body: nil)
        let result = validator.validate(data: &invalidNil)
        XCTAssertFalse(result)
    }

    func test_validate_isValid_ifBodyIsWithinRange() {
        let validator = LengthOfBodyValidator(allowedCharacterCount: 5...128)

        var invalidEmpty = logData(body: "")
        var invalidShort = logData(body: "ab")
        var invalidAboveMaximum = logData(
            body: String(repeating: "a", count: validator.allowedCharacterCount.upperBound + 1)
        )

        var validMinimum = logData(body: String(repeating: "a", count: validator.allowedCharacterCount.lowerBound))
        var validMaximum = logData(body: String(repeating: "a", count: validator.allowedCharacterCount.upperBound))

        XCTAssertFalse(validator.validate(data: &invalidEmpty))
        XCTAssertFalse(validator.validate(data: &invalidShort))
        XCTAssertFalse(validator.validate(data: &invalidAboveMaximum))

        XCTAssertTrue(validator.validate(data: &validMinimum))
        XCTAssertTrue(validator.validate(data: &validMaximum))
    }

}
