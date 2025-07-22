//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceOTelInternal
import Foundation
import OpenTelemetrySdk

@testable import EmbraceCore

class MockSpanDataValidator: SpanDataValidator {

    let isValid: Bool
    var didValidate = false

    init(isValid: Bool) {
        self.isValid = isValid
    }

    func validate(data: inout SpanData) -> Bool {
        didValidate = true
        return isValid
    }
}
