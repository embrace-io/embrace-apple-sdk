//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceOTel

/// Validates the length of ``SpanData.name``. 
/// This compares the length of the String in characters, not bytes.
class LengthOfNameValidator: SpanDataValidator {

    let allowedCharacterCount: ClosedRange<Int>

    init(allowedCharacterCount: ClosedRange<Int> = 1...50) {
        self.allowedCharacterCount = allowedCharacterCount
    }

    func validate(data: inout SpanData) -> Bool {
        return allowedCharacterCount.contains(data.name.count)
    }
}
