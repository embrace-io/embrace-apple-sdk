//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceOTelInternal

/// Validates the length of ``SpanData.name``. 
/// This compares the length of the String in characters, not bytes.
class LengthOfNameValidator: SpanDataValidator {

    let allowedCharacterCount: ClosedRange<Int>

    init(allowedCharacterCount: ClosedRange<Int> = 1...50) {
        self.allowedCharacterCount = allowedCharacterCount
    }

    func validate(data: inout SpanData) -> Bool {
        guard shouldValidate(data: data) else {
            return true
        }
        return allowedCharacterCount.contains(data.name.count)
    }

    private func shouldValidate(data: SpanData) -> Bool {
        return data.embType != .networkHTTP
    }
}
