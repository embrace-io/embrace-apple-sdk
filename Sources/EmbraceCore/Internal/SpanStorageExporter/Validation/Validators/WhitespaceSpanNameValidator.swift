//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceOTelInternal
#endif
import OpenTelemetrySdk

class WhitespaceSpanNameValidator: SpanDataValidator {
    func validate(data: inout SpanData) -> Bool {
        let trimSet: CharacterSet = .whitespacesAndNewlines.union(.controlCharacters)
        return !data.name.trimmingCharacters(in: trimSet).isEmpty
    }
}
