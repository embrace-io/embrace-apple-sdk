//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import Foundation

/// A `Backtracer` whose remote-thread captures come back empty for the first `failures` calls and
/// then return a single fake frame, emulating a capture that loses the backtracer's capture lock.
///
/// The buffer entry point runs while the target thread is suspended, so it only touches atomics
/// and the caller-owned buffer — no allocation.
final class ScriptedBacktracer: NSObject, Backtracer {

    static let fakeFrame: FrameAddress = 0x1000

    /// Number of initial captures that return no frames. `Int.max` makes every capture fail.
    let failures: Int

    private let callCount = EmbraceAtomic<Int64>(0)

    /// Number of remote-thread captures attempted so far.
    var calls: Int { Int(callCount.load()) }

    init(failures: Int) {
        self.failures = failures
    }

    func backtrace(of thread: pthread_t) -> [FrameAddress] {
        Thread.callStackReturnAddresses.map { $0.uintValue }
    }

    /// A call with `capacity == 0` is a no-op that is not counted, so callers can warm up the ObjC
    /// dispatch for this method without consuming a scripted capture.
    func backtrace(of thread: pthread_t, into buffer: UnsafeMutablePointer<FrameAddress>, capacity: Int) -> Int {
        guard capacity > 0 else { return 0 }
        let call = callCount.fetchAdd(1) + 1
        guard call > Int64(failures) else { return 0 }
        buffer[0] = Self.fakeFrame
        return 1
    }
}
