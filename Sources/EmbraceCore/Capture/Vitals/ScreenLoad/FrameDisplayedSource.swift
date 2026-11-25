//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// Called with a frame's time, in seconds on the system uptime base (`ProcessInfo.systemUptime`,
/// the same base as `CACurrentMediaTime()`).
///
/// This clock pauses while the device sleeps. That differs from hang detection
/// (`CLOCK_MONOTONIC_RAW`) and from view capture (`Date`), so the screen-load tracker must take its
/// other timestamps on the uptime base too.
typealias FrameDisplayedHandler = (_ uptime: TimeInterval) -> Void

/// Reports the first frame displayed after a request, keeping the screen-load tracker free of
/// QuartzCore and run-loop timing. The Android equivalent is the first `Choreographer` frame after
/// navigation end.
protocol FrameDisplayedSource: AnyObject {

    /// Calls `handler` once, at the first frame displayed after the next Core Animation commit.
    ///
    /// Call from the main thread only. A call from another thread is dropped and logged, and its
    /// `handler` is never called. `handler` is called on the main thread.
    func requestNextFrame(_ handler: @escaping FrameDisplayedHandler)

    /// Cancels every pending request without calling it, and releases any resources. This includes
    /// requests answered by the same frame as a handler that calls `stop()`. Requests made
    /// afterwards work as normal.
    ///
    /// Call from the main thread only. A call from another thread is dropped and logged.
    func stop()
}
