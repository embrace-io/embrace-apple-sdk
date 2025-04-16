//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceOTelInternal
import EmbraceSemantics
import EmbraceCommonInternal
#endif
import OpenTelemetrySdk

/// Validates the length of ``SpanData.name``.
/// This compares the length of the String in characters, not bytes.
class LengthOfNameValidator: SpanDataValidator {
    private static let allowList: [SpanType] = [.networkRequest, .view, .viewLoad]
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
        return !LengthOfNameValidator.allowList.contains(data.embType)
    }
}
