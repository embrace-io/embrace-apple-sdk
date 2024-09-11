//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceCore
import EmbraceOTelInternal
import OpenTelemetrySdk

final class LogDataValidationTests: XCTestCase {

    let dummyLogData = ReadableLogRecord(
        resource: .init(),
        instrumentationScopeInfo: .init(),
        timestamp: Date(),
        attributes: [:]
    )

    func test_execute_callsValidateOnAllValidators_ifAllValid() throws {
        let first = MockLogDataValidator(isValid: true)
        let second = MockLogDataValidator(isValid: true)
        let validation = LogDataValidation(validators: [first, second])

        var toValidate = dummyLogData
        let result = validation.execute(log: &toValidate)
        XCTAssertTrue(result)

        XCTAssertTrue(first.didValidate)
        XCTAssertTrue(second.didValidate)
    }

    func test_execute_skipsFollowingValidators_afterInvalid() throws {
        let first = MockLogDataValidator(isValid: true)
        let second = MockLogDataValidator(isValid: false)
        let third = MockLogDataValidator(isValid: true)
        let validation = LogDataValidation(validators: [first, second, third])

        var toValidate = dummyLogData
        let result = validation.execute(log: &toValidate)
        XCTAssertFalse(result)

        XCTAssertTrue(first.didValidate)
        XCTAssertTrue(second.didValidate)
        XCTAssertFalse(third.didValidate)
    }

}
