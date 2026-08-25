//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import TestSupport
import TestSupportObjc
import XCTest

@testable import EmbraceCore
@testable import EmbraceIO

/// A distinctively-named, deliberately un-inlinable self-capture site.
///
/// It walks its *own* thread (`pthread_self()`), so `_takeSnapshot` applies
/// ``EmbraceBacktrace/selfCaptureFrameSkip``. If that constant is correct, this function is frame 0
/// of the returned backtrace. `@inline(never)` guarantees the frame exists so the test isn't fooled
/// by the *caller's* inlining — only the SDK's internal wrapper depth is under test.
@inline(never)
private func embFrameSkipPinnedCaller() -> EmbraceBacktrace {
    EmbraceBacktrace.backtrace(of: pthread_self(), threadIndex: 0)
}

// The suspend-based (off-main) capture path only exists on platforms where the hang feature ships.
// On watchOS thread suspension is unavailable (`emb_thread_suspend` is a no-op), and macOS is gated
// out of the feature — so walking another, un-suspended thread there yields nothing. These helpers
// and the tests that use them are scoped to match.
#if !os(watchOS) && !os(macOS)

    /// A distinctively-named, un-inlinable function a background thread parks in while another thread
    /// suspends and walks it. Publishes its own `pthread_t`, signals `ready`, then blocks on `hold` —
    /// so while the walker runs, this frame is guaranteed to be on the parked thread's stack.
    @inline(never)
    private func embFrameSkipParkedThread(
        ready: DispatchSemaphore,
        hold: DispatchSemaphore,
        publish: (pthread_t) -> Void
    ) {
        publish(pthread_self())
        ready.signal()
        hold.wait()
    }

    private final class PThreadBox {
        var value: pthread_t?
    }

#endif

/// Pins the hardcoded backtrace frame-skip constants against the *real* SDK capture chain.
///
/// These constants are wrapper *depth*, not semantics: they only stay correct while the internal
/// call chain above the caller is unchanged and the optimizer doesn't inline a wrapper away. This
/// test converts a silent regression (traces that start one frame off) into a loud CI failure that
/// points at the constant to update. It must pass in **both Debug and Release** — inlining can shift
/// the depth between configurations, and if it does, a single constant is insufficient.
final class BacktraceFrameSkipTests: XCTestCase {

    override class func setUp() {
        super.setUp()
        // Wires the default backtracer + symbolicator (`KSCrashBacktracing`) onto `Embrace.client`,
        // which `EmbraceBacktrace` reads. Without it, capture returns no frames.
        _ = try? Embrace.setup(options: Embrace.Options(appId: "myApp")).start()
    }

    override class func tearDown() {
        _ = try? Embrace.client?.stop()
        Embrace.client = nil
        super.tearDown()
    }

    func test_selfCaptureFrameSkip_landsFrameZeroOnCaller() throws {
        // ksbic_init (KSCrash binary-image cache) is not safe under sanitizer instrumentation:
        // TSan aborts; ASan deadlocks until the job cap fires. Symbolication is required here.
        try XCTSkipIfSanitizing("KSCrash symbolication is incompatible with sanitizer instrumentation")

        let frames = embFrameSkipPinnedCaller().threads.first?.callstack.frames(symbolicated: true) ?? []
        let topNames = frames.prefix(8).map { $0.symbol?.name ?? "<nil>" }

        XCTAssertTrue(
            frames.first?.symbol?.name.contains("embFrameSkipPinnedCaller") == true,
            """
            selfCaptureFrameSkip (\(EmbraceBacktrace.selfCaptureFrameSkip)) no longer lands frame 0 on \
            the self-capture caller. Top frames after the skip were:
            \(topNames.enumerated().map { "  [\($0.offset)] \($0.element)" }.joined(separator: "\n"))
            The SDK capture-wrapper depth changed (an internal refactor, or the optimizer inlined a \
            wrapper). Find `embFrameSkipPinnedCaller` in the list above, set `selfCaptureFrameSkip` so \
            it becomes frame 0, and re-run this test in Debug AND Release before landing the change.
            """
        )
    }

    /// Exercises the off-main / `canSuspend == true` path: allocate buffer → suspend → alloc-free
    /// `backtrace(of:into:capacity:)` → resume → slice. Proves the alloc-free route returns the
    /// *target* thread's real frames with skip 0 (no SDK plumbing on top).
    ///
    /// Only meaningful where the feature ships: watchOS can't suspend threads and macOS is gated out.
    #if !os(watchOS) && !os(macOS)
        func test_suspendCapture_returnsTargetFramesWithNoSDKPlumbingOnTop() throws {
            try XCTSkipIfSanitizing("KSCrash symbolication is incompatible with sanitizer instrumentation")

            let ready = DispatchSemaphore(value: 0)
            let hold = DispatchSemaphore(value: 0)
            let box = PThreadBox()

            let thread = Thread {
                embFrameSkipParkedThread(ready: ready, hold: hold) { box.value = $0 }
            }
            thread.name = "emb.frameskip.parked"
            thread.start()

            // `ready` ordering guarantees `box.value` is published and the thread is inside
            // `embFrameSkipParkedThread` (about to / already blocked on `hold`) before we walk it.
            ready.wait()
            defer { hold.signal() }  // let the parked thread finish no matter how the test exits

            let target = try XCTUnwrap(box.value, "parked thread did not publish its pthread_t")
            let frames =
                EmbraceBacktrace.backtrace(of: target, threadIndex: 0)
                .threads.first?.callstack.frames(symbolicated: true) ?? []
            let names = frames.compactMap { $0.symbol?.name }

            // (a) alloc-free suspend walk produced real frames.
            XCTAssertFalse(frames.isEmpty, "suspend-path capture returned no frames")

            // (b) we walked the RIGHT thread and skip 0 kept its real code.
            XCTAssertTrue(
                names.contains { $0.contains("embFrameSkipParkedThread") },
                "parked function missing from the target thread's backtrace; names: \(names.prefix(12))"
            )

            // (c) skip 0 on the suspend path means the SDK's own capture wrappers are NOT on top
            //     (that was the bug on the self path when applied to a suspended thread).
            let topName = frames.first?.symbol?.name ?? ""
            for wrapper in ["_takeSnapshot", "takeSnapshot", "EmbraceBacktrace"] {
                XCTAssertFalse(
                    topName.contains(wrapper),
                    "SDK wrapper '\(wrapper)' leaked to the top of a suspended-thread capture: \(topName)"
                )
            }
        }
    #endif
}

/// Proves the thread-suspend backtrace window performs **no heap allocation** — the property that
/// prevents the #423-class whole-process deadlock (walker allocates while the suspended thread holds
/// the allocator lock).
///
/// The `test_...positiveControl...` test is not optional bookkeeping: a zero-violation result in the
/// real test is only meaningful if we've proven the tripwire actually fires. If the positive control
/// ever fails, `malloc_logger` isn't being invoked in this environment and the sentinel must move to
/// symbol interposition (fishhook) before its results can be trusted.
///
/// Scoped to the platforms that have a suspend window at all (watchOS can't suspend threads; macOS is
/// gated out of the feature).
#if !os(watchOS) && !os(macOS)

    final class SuspendWindowSentinelTests: XCTestCase {

        override class func setUp() {
            super.setUp()
            _ = try? Embrace.setup(options: Embrace.Options(appId: "myApp")).start()
        }

        override class func tearDown() {
            _ = try? Embrace.client?.stop()
            Embrace.client = nil
            super.tearDown()
        }

        /// Positive control: a deliberate in-window allocation MUST be seen. Validates the mechanism.
        func test_sentinel_positiveControl_detectsInWindowAllocation() throws {
            try XCTSkipIfSanitizing("malloc interposition conflicts with sanitizer allocators")

            EMBSuspendWindowSentinelArm()
            defer { EMBSuspendWindowSentinelDisarm() }
            EMBSuspendWindowSentinelResetViolations()

            EMBSuspendWindowSentinelBeginWindow()
            let p = malloc(32)
            XCTAssertNotNil(p)
            free(p)
            EMBSuspendWindowSentinelEndWindow()

            XCTAssertGreaterThan(
                EMBSuspendWindowSentinelViolationCount(), 0,
                """
                The sentinel did not observe a deliberate in-window allocation. `malloc_logger` is not \
                firing in this environment, so a zero-violation result in the real test is meaningless. \
                Switch the sentinel to symbol interposition (fishhook) before trusting it.
                """
            )
        }

        #if DEBUG
            /// The real test: walking a suspended thread must allocate nothing between suspend and resume.
            func test_suspendWindow_performsNoAllocation() throws {
                try XCTSkipIfSanitizing("KSCrash + malloc interposition are unsafe under sanitizer instrumentation")

                let ready = DispatchSemaphore(value: 0)
                let hold = DispatchSemaphore(value: 0)
                let box = PThreadBox()
                let thread = Thread {
                    embFrameSkipParkedThread(ready: ready, hold: hold) { box.value = $0 }
                }
                thread.name = "emb.sentinel.parked"
                thread.start()
                ready.wait()
                defer { hold.signal() }
                let target = try XCTUnwrap(box.value, "parked thread did not publish its pthread_t")

                EMBSuspendWindowSentinelArm()
                EmbraceBacktraceSuspendWindowProbe.willEnter = { EMBSuspendWindowSentinelBeginWindow() }
                EmbraceBacktraceSuspendWindowProbe.didExit = { EMBSuspendWindowSentinelEndWindow() }
                defer {
                    EmbraceBacktraceSuspendWindowProbe.willEnter = nil
                    EmbraceBacktraceSuspendWindowProbe.didExit = nil
                    EMBSuspendWindowSentinelDisarm()
                }
                EMBSuspendWindowSentinelResetViolations()

                _ = EmbraceBacktrace.backtrace(of: target, threadIndex: 0)

                XCTAssertEqual(
                    EMBSuspendWindowSentinelViolationCount(), 0,
                    """
                    An allocation occurred inside the thread-suspend window — the #423-class deadlock \
                    hazard. Inspect what runs between `willEnter`/`didExit` in `_takeSnapshot` (the \
                    `backtracer.backtrace(of:into:capacity:)` call and anything it triggers).
                    """
                )
            }
        #endif
    }

#endif
