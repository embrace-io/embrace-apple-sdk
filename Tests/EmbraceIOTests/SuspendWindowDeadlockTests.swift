//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS) && !os(macOS)

    import Foundation
    import ObjectiveC
    import TestSupport
    import XCTest
    import os

    #if !EMBRACE_COCOAPOD_BUILDING_SDK
        import EmbraceCommonInternal
    #endif

    @testable import EmbraceCore
    @testable import EmbraceIO

    private final class PThreadBox {
        var value: pthread_t?
    }

    /// Deadlock amplifier for the thread-suspend backtrace window.
    ///
    /// A backtrace suspends the target thread and walks it. If that walk ever needed a lock the
    /// **suspended** thread is holding, the process would deadlock (the #423 class of bug). These
    /// tests deliberately suspend a victim thread that is holding — or hammering — each lock class
    /// and assert the walk still completes within a timeout.
    ///
    /// The **allocator** case is the load-bearing one: `malloc`'s lock is the only lock the walk
    /// could plausibly contend on, so a victim caught mid-`malloc` is the real scenario. The explicit
    /// app-lock cases prove the walk is robust when the victim is suspended mid-critical-section (how
    /// a real hung main thread often looks) and guard against future changes that add runtime work to
    /// the window.
    ///
    /// A genuine deadlock surfaces as the sampling thread never signaling `done` → the wait times out
    /// → the test fails, instead of hanging the whole suite.
    final class SuspendWindowDeadlockTests: XCTestCase {

        override class func setUp() {
            super.setUp()
            _ = try? Embrace.setup(options: Embrace.Options(appId: "myApp")).start()
        }

        override class func tearDown() {
            _ = try? Embrace.client?.stop()
            Embrace.client = nil
            super.tearDown()
        }

        /// Walks `victim` on a background thread and returns whether it finished within `timeout`.
        private func sampleCompletes(victim: pthread_t, timeout: TimeInterval = 5) -> Bool {
            let done = DispatchSemaphore(value: 0)
            DispatchQueue.global(qos: .userInitiated).async {
                _ = EmbraceBacktrace.backtrace(of: victim, threadIndex: 0)
                done.signal()
            }
            return done.wait(timeout: .now() + timeout) == .success
        }

        /// Spawns a victim thread that acquires a lock (via `enter`), parks while holding it, is
        /// sampled, then releases (via `release`) and finishes — all before returning, so the caller
        /// can safely tear down lock storage.
        private func assertNoDeadlockWhileVictimHolds(
            _ lockName: String,
            enter: @escaping () -> Void,
            release: @escaping () -> Void,
            file: StaticString = #filePath,
            line: UInt = #line
        ) {
            let ready = DispatchSemaphore(value: 0)
            let mayRelease = DispatchSemaphore(value: 0)
            let finished = DispatchSemaphore(value: 0)
            let box = PThreadBox()

            let victim = Thread {
                enter()
                box.value = pthread_self()
                ready.signal()
                mayRelease.wait()  // park WHILE HOLDING the lock, across the sampling
                release()
                finished.signal()
            }
            victim.name = "emb.deadlock.victim"
            victim.start()
            ready.wait()

            guard let target = box.value else {
                XCTFail("victim did not publish its pthread_t", file: file, line: line)
                return
            }

            let completed = sampleCompletes(victim: target)

            mayRelease.signal()  // let the victim release the lock…
            finished.wait()  // …and fully finish before the caller frees lock storage

            XCTAssertTrue(
                completed,
                "Sampling a thread holding \(lockName) did not complete within the timeout — "
                    + "the suspend-window walk likely needs that lock (deadlock).",
                file: file,
                line: line
            )
        }

        func test_noDeadlock_victimHolds_osUnfairLock() throws {
            try XCTSkipIfSanitizing("thread suspension + KSCrash walk are unsafe under sanitizer instrumentation")

            let lock = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
            lock.initialize(to: os_unfair_lock())
            defer {
                lock.deinitialize(count: 1)
                lock.deallocate()
            }

            assertNoDeadlockWhileVictimHolds(
                "os_unfair_lock",
                enter: { os_unfair_lock_lock(lock) },
                release: { os_unfair_lock_unlock(lock) }
            )
        }

        func test_noDeadlock_victimHolds_pthreadMutex() throws {
            try XCTSkipIfSanitizing("thread suspension + KSCrash walk are unsafe under sanitizer instrumentation")

            let mutex = UnsafeMutablePointer<pthread_mutex_t>.allocate(capacity: 1)
            XCTAssertEqual(pthread_mutex_init(mutex, nil), 0)
            defer {
                pthread_mutex_destroy(mutex)
                mutex.deallocate()
            }

            assertNoDeadlockWhileVictimHolds(
                "pthread_mutex",
                enter: { pthread_mutex_lock(mutex) },
                release: { pthread_mutex_unlock(mutex) }
            )
        }

        func test_noDeadlock_victimHolds_objcSync() throws {
            try XCTSkipIfSanitizing("thread suspension + KSCrash walk are unsafe under sanitizer instrumentation")

            let object = NSObject()
            assertNoDeadlockWhileVictimHolds(
                "@synchronized (objc_sync)",
                enter: { objc_sync_enter(object) },
                release: { objc_sync_exit(object) }
            )
        }

        /// The victim hammers the ObjC runtime, so suspending it repeatedly catches it holding the
        /// runtime lock. A walk that dispatches through the `@objc` `Backtracer` protocol needs that
        /// same lock on a cold method cache, which wedges the whole process.
        ///
        /// The per-iteration cache flush is what makes this bite: a warm cache resolves the selector
        /// without the lock, so without flushing a regressed build would usually pass.
        func test_noDeadlock_victimHammersObjCRuntime() throws {
            try XCTSkipIfSanitizing("thread suspension + KSCrash walk are unsafe under sanitizer instrumentation")

            let backtracer = try XCTUnwrap(Embrace.client?.options.backtracer, "no backtracer configured")
            let backtracerClass: AnyClass = object_getClass(backtracer)!

            let running = EmbraceAtomic<Bool>(true)
            let ready = DispatchSemaphore(value: 0)
            let box = PThreadBox()

            // Each of these runtime mutations takes the runtime lock, so a suspend lands inside it
            // often. Disposing keeps the class count bounded.
            let victim = Thread {
                box.value = pthread_self()
                ready.signal()
                var counter = 0
                while running.load(order: .relaxed) {
                    counter += 1
                    if let cls = objc_allocateClassPair(NSObject.self, "EMBRuntimeLockProbe\(counter)", 0) {
                        objc_registerClassPair(cls)
                        objc_disposeClassPair(cls)
                    }
                }
            }
            victim.name = "emb.deadlock.objcruntime"
            victim.start()
            ready.wait()
            defer { running.store(false, order: .relaxed) }

            let target = try XCTUnwrap(box.value, "victim did not publish its pthread_t")

            let noop: @convention(c) (AnyObject, Selector) -> Void = { _, _ in }
            let noopImp = unsafeBitCast(noop, to: IMP.self)

            for iteration in 0..<200 {
                // Cold-cache the backtracer's class before each sample (see doc comment).
                class_addMethod(backtracerClass, NSSelectorFromString("embCacheFlush\(iteration)"), noopImp, "v@:")

                XCTAssertTrue(
                    sampleCompletes(victim: target),
                    "Sampling stalled on iteration \(iteration) while the victim hammered the ObjC "
                        + "runtime — the suspend-window walk is taking the runtime lock (deadlock)."
                )
            }
        }

        /// The load-bearing case: the victim continuously allocates/frees, so suspending it
        /// repeatedly catches it mid-`malloc` holding the allocator lock. If the alloc-free window
        /// regressed and started allocating, this would deadlock and time out.
        func test_noDeadlock_victimHammersAllocator() throws {
            try XCTSkipIfSanitizing("thread suspension + KSCrash walk are unsafe under sanitizer instrumentation")

            let running = EmbraceAtomic<Bool>(true)
            let ready = DispatchSemaphore(value: 0)
            let box = PThreadBox()

            let victim = Thread {
                box.value = pthread_self()
                ready.signal()
                while running.load(order: .relaxed) {
                    if let p = malloc(64) {
                        memset(p, 1, 64)
                        free(p)
                    }
                }
            }
            victim.name = "emb.deadlock.allocator"
            victim.start()
            ready.wait()
            defer { running.store(false, order: .relaxed) }

            let target = try XCTUnwrap(box.value, "victim did not publish its pthread_t")

            // Many attempts to raise the odds of catching the victim inside the allocator lock.
            for iteration in 0..<200 {
                XCTAssertTrue(
                    sampleCompletes(victim: target),
                    "Sampling stalled on iteration \(iteration) while the victim hammered the allocator "
                        + "— the suspend-window walk is not allocation-free (deadlock)."
                )
            }
        }
    }

#endif
