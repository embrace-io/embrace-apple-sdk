//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public enum EmbraceExampleCrash: String, CaseIterable {
    case fatalError
    case unwrapOptional
    case indexOutOfBounds
}

public enum EmbraceCrashHelper {
    /// Crash the app in the prescribed manner.
    /// This method is used to test the Embrace Crash Reporter.
    ///
    /// The Xcode debugger will prevent the EmbraceCrashReporter from properly handling crashes,
    /// when validating that crashes appear in the Embrace dashboard, be sure to run without the Xcode
    /// debugger connected (without 'Debug executable' checked in Edit Scheme -> Run settings).
    ///
    /// - Note: Do not use in production
    public static func crash(example: EmbraceExampleCrash = .unwrapOptional) -> Never {
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
