//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceOTel

/// Validates the length of ``ReadableLogRecord.body``.
/// This compares the length of the String in characters, not bytes.
/// The range defaults  to (1...4000) characters
class LengthOfBodyValidator: LogDataValidator {

    let allowedCharacterCount: ClosedRange<Int>

    init(allowedCharacterCount: ClosedRange<Int> = 1...4000) {
        self.allowedCharacterCount = allowedCharacterCount
    }

    func validate(data: inout ReadableLogRecord) -> Bool {
        guard let body = data.body else {
            return false
        }
        return allowedCharacterCount.contains(body.count)
    }
}
