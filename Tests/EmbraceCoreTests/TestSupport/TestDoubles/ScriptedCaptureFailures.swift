//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import Foundation

@testable import EmbraceCore

/// Makes the first `failures` remote-thread captures come back with no frames, emulating a capture
/// that loses the backtracer's capture lock to another stack walk. Captures after that keep their
/// real frames.
///
/// Works through `EmbraceBacktraceSuspendWindowProbe.filterCapturedCount`, so only one instance
/// should be installed at a time. Call `uninstall()` when done.
final class ScriptedCaptureFailures {

    /// Number of initial captures that return no frames. `Int.max` makes every capture fail.
    let failures: Int

    private let callCount = EmbraceAtomic<Int64>(0)

    /// Number of remote-thread captures attempted since `install()`.
    var calls: Int { Int(callCount.load()) }

    init(failures: Int) {
        self.failures = failures
    }

    func install() {
        EmbraceBacktraceSuspendWindowProbe.filterCapturedCount = { [callCount, failures] count in
            let call = callCount.fetchAdd(1) + 1
            return call > Int64(failures) ? count : 0
        }
    }

    func uninstall() {
        EmbraceBacktraceSuspendWindowProbe.filterCapturedCount = nil
    }
}
