//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceOTel

class WhitespaceSpanNameValidator: SpanDataValidator {
    func validate(data: inout SpanData) -> Bool {
        let trimSet: CharacterSet = .whitespacesAndNewlines.union(.controlCharacters)
        return !data.name.trimmingCharacters(in: trimSet).isEmpty
    }
}
