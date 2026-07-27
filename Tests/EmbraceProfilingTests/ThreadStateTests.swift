//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS)

    import Darwin
    import XCTest

    @testable import EmbraceProfiling

    /// The Swift `ThreadState` enum and the C `emb_thread_run_state_t` both independently mirror the
    /// Mach `TH_STATE_*` constants (the C side is locked by a `_Static_assert` in emb_ring_buffer.h).
    /// This anchors the Swift side to the same source of truth so the two can't silently drift.
    final class ThreadStateTests: XCTestCase {
        func test_threadState_rawValuesMatchMachConstants() {
            XCTAssertEqual(ThreadState.running.rawValue, UInt8(TH_STATE_RUNNING))
            XCTAssertEqual(ThreadState.stopped.rawValue, UInt8(TH_STATE_STOPPED))
            XCTAssertEqual(ThreadState.waiting.rawValue, UInt8(TH_STATE_WAITING))
            XCTAssertEqual(ThreadState.uninterruptible.rawValue, UInt8(TH_STATE_UNINTERRUPTIBLE))
            XCTAssertEqual(ThreadState.halted.rawValue, UInt8(TH_STATE_HALTED))
        }

        /// 255 is the "couldn't capture" sentinel — a value Mach never returns for `run_state`.
        func test_threadState_unknownIsSentinel() {
            XCTAssertEqual(ThreadState.unknown.rawValue, 255)
            XCTAssertNil(ThreadState(rawValue: 254))  // unmapped values decode to nil (→ .unknown at call sites)
        }
    }

#endif
