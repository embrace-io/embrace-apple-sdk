//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// Serializes every entry point that reaches KSCrash's process-global C state.
///
/// KSCrash's binary-image cache (`ksbic_init`) rewrites the global `g_all_image_infos` on *every*
/// call — it has no init guard — and the Swift demangle filter lazily caches the `swift_demangle`
/// function pointer in another global. Both are written without synchronization, so the
/// crash-reporter install path (`Embrace.start` → `KSCrashReporter.install` → `ksbic_init`) races
/// the background log symbolication path (`LogController.createLog` → `EmbraceBacktraceFrame.symbolicated`
/// → `ksbt_symbolicateAddress` → `ksbic_init`).
///
/// Every call site that triggers those lazy inits — symbolication, backtrace capture, and
/// crash-reporter install — funnels through this lock so they can never run concurrently.
public enum KSCrashGlobalsLock {
    private static let lock = ReadWriteLock()

    public static func withLock<ReturnValue>(_ body: () throws -> ReturnValue) rethrows -> ReturnValue {
        try lock.lockedForWriting(body)
    }
}
