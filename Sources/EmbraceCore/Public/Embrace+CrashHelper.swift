//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal

extension Embrace {
    /// Crash the app in the prescribed manner.
    /// This method is used to test the Embrace Crash Reporter.
    ///
    /// The Xcode debugger will prevent the EmbraceCrashReporter from properly handling crashes,
    /// when validating that crashes appear in the Embrace dashboard, be sure to run without the Xcode
    /// debugger connected (without 'Debug executable' checked in Edit Scheme -> Run settings).
    ///
    /// - Note: Do not use in production
    public func crash(type: ExampleCrash = .fatalError) -> Never {
        CrashHelper.crash(example: type)
    }
}
