//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

/// Validates the length of ``ReadableLogRecord.body``.
/// This compares the length of the String in characters, not bytes.
/// The range defaults  to (1...4000) characters
class LengthOfBodyValidator: LogDataValidator {

    let allowedCharacterCount: ClosedRange<Int>

    init(allowedCharacterCount: ClosedRange<Int> = 0...4000) {
        self.allowedCharacterCount = allowedCharacterCount
    }

    func validate(data: inout EmbraceLog) -> Bool {
        return allowedCharacterCount.contains(data.body.description.count)
    }
}
