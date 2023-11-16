//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public enum ExampleCrash: String, CaseIterable {
    case fatalError
    case unwrapOptional
    case indexOutOfBounds
}

enum CrashHelper { }
extension CrashHelper {
    static func crash(example: ExampleCrash = .unwrapOptional) -> Never {
        switch example {
        case .fatalError:
            fatalError("Example crash")
        case .unwrapOptional:
            _ = Optional<Any>.none!

        case .indexOutOfBounds:
            _ = [1, 2, 3][4]
        }

        // DEV: All cases in above switch should lead to a crash - but if they don't...
        fatalError("Example crash did of type `\(example)` did not actually cause a crash...")
    }
}
