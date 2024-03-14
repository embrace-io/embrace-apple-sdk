//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceCore
@testable import OpenTelemetrySdk

final class SpanDataValidationTests: XCTestCase {

    let dummySpanData = SpanData(
        traceId: .random(),
        spanId: .random(),
        name: "example",
        kind: .internal,
        startTime: Date(),
        endTime: Date()
    )

    func test_execute_callsValidateOnAllValidators_ifAllValid() throws {
        let first = MockSpanDataValidator(isValid: true)
        let second = MockSpanDataValidator(isValid: true)
        let validation = SpanDataValidation(validators: [first, second])

        var toValidate = dummySpanData
        let result = validation.execute(spanData: &toValidate)
        XCTAssertTrue(result)

        XCTAssertTrue(first.didValidate)
        XCTAssertTrue(second.didValidate)
    }

    func test_execute_skipsFollowingValidators_afterInvalid() throws {
        let first = MockSpanDataValidator(isValid: true)
        let second = MockSpanDataValidator(isValid: false)
        let third = MockSpanDataValidator(isValid: true)
        let validation = SpanDataValidation(validators: [first, second, third])

        var toValidate = dummySpanData
        let result = validation.execute(spanData: &toValidate)
        XCTAssertFalse(result)

        XCTAssertTrue(first.didValidate)
        XCTAssertTrue(second.didValidate)
        XCTAssertFalse(third.didValidate)
    }

}
