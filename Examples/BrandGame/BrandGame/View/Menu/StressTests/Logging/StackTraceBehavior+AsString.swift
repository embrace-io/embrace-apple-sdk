//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal

extension StackTraceBehavior {
    func asString() -> String {
        switch self {
        case .default:
            return "Default"
        case .notIncluded:
            return "Not Included"
        }
    }
}
