//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceOTelInternal
import OpenTelemetrySdk

@testable import EmbraceCore

class MockLogDataValidator: LogDataValidator {

    let isValid: Bool
    private(set) var didValidate = false

    init(isValid: Bool) {
        self.isValid = isValid
    }

    func validate(data: inout ReadableLogRecord) -> Bool {
        didValidate = true
        return isValid
    }
}
