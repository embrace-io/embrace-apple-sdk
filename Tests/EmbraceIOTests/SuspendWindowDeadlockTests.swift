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
        import EmbraceKSCrashBacktraceSupport
    #endif

    @testable import EmbraceCore
    @testable import EmbraceIO

    private final class PThreadBox {
        var value: pthread_t?
        var port: mach_port_t = mach_port_t(MACH_PORT_NULL)
    }

    /// Deadlock amplifier for the thread-suspend backtrace window.
    ///
    /// A backtrace suspends the target thread and walks it. If that walk ever needed a lock the
    /// **suspended** thread is holding, the process would deadlock (the #423 class of bug). These
    /// tests deliberately suspend a victim thread that is holding — or hammering — each lock class
    /// and assert the walk still completes within a timeout.
    ///
    /// The **allocator** and **libpthread thread-list** cases are the load-bearing ones: those are the
    /// locks the walk itself could plausibly contend on (`malloc`, and pthread handle lookups such as
    /// `pthread_mach_thread_np`), so a victim caught mid-`malloc` or mid-`pthread_create` is the real
    /// scenario. The explicit app-lock cases prove the walk is robust when the victim is suspended
    /// mid-critical-section (how a real hung main thread often looks) and guard against future changes
    /// that add runtime work to the window.
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
        /// A warm method cache resolves the selector without taking the lock, so the cache has to be
        /// cold for this to bite. The victim's own class churn already keeps it cold — verified by
        /// reproducing the deadlock with the explicit flush below removed — so that flush is only
        /// belt-and-braces, not the mechanism.
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

            let flushSelector = NSSelectorFromString("embCacheFlush")
            for iteration in 0..<200 {
                // Cold-cache the backtracer's class before each sample (see doc comment). Replacing
                // one selector rather than adding a new one each time keeps the class from
                // accumulating 200 methods that outlive this test.
                class_replaceMethod(backtracerClass, flushSelector, noopImp, "v@:")

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

        /// Runs `body` in a loop on a victim thread and samples it repeatedly, so some suspends are
        /// likely to land while `body` holds its lock. `body` returns whether it did the lock-taking
        /// work, so a victim that only ever fails fast can't make the test pass vacuously.
        private func assertNoDeadlockWhileVictimHammers(
            _ what: String,
            body: @escaping () -> Bool,
            file: StaticString = #filePath,
            line: UInt = #line
        ) throws {
            // Pin the built-in path this suite guards: with no backtracer nothing is suspended, and a
            // custom one takes a different branch, so either would pass without testing anything.
            _ = try XCTUnwrap(
                Embrace.client?.options.backtracer as? KSCrashBacktracing,
                "expected the built-in KSCrashBacktracing backtracer",
                file: file,
                line: line
            )

            let running = EmbraceAtomic<Bool>(true)
            let successes = EmbraceAtomic<Int64>(0)
            let ready = DispatchSemaphore(value: 0)
            let finished = DispatchSemaphore(value: 0)
            let box = PThreadBox()

            let victim = Thread {
                box.value = pthread_self()
                box.port = pthread_mach_thread_np(pthread_self())  // own handle: no list lock
                ready.signal()
                while running.load(order: .relaxed) {
                    if body() {
                        successes.fetchAdd(1, order: .relaxed)
                    }
                }
                finished.signal()
            }
            victim.name = "emb.deadlock.hammer"
            victim.start()
            ready.wait()
            // Wait for the victim to stop running `body`, so callers can tear down what it uses.
            // Bounded: after a deadlock the victim stays suspended and never gets here.
            defer {
                running.store(false, order: .relaxed)
                _ = finished.wait(timeout: .now() + 5)
            }

            let target = try XCTUnwrap(box.value, "victim did not publish its pthread_t", file: file, line: line)

            for iteration in 0..<200 {
                guard sampleCompletes(victim: target) else {
                    // The sampler is wedged with the victim suspended while holding the lock. Resume
                    // the victim so it releases the lock: otherwise every later thread creation in the
                    // process (the next test, GCD workers) blocks and the run hangs instead of failing.
                    // The sampler's own resume then just returns `KERN_FAILURE`.
                    thread_resume(box.port)
                    XCTFail(
                        "Sampling stalled on iteration \(iteration) while the victim hammered \(what) — the "
                            + "suspend-window walk is taking a lock the suspended victim holds (most likely "
                            + "libpthread's thread-list lock via a pthread handle lookup): deadlock.",
                        file: file,
                        line: line
                    )
                    // Stop at the first stall; later iterations would only add timeouts.
                    break
                }
            }

            XCTAssertGreaterThan(
                successes.load(),
                0,
                "the victim never completed \(what), so nothing was exercised",
                file: file,
                line: line
            )
        }

        /// The victim holds libpthread's thread-list lock inside `pthread_create` and `pthread_join`
        /// (EMBR-14336: app code creating/joining threads while the main thread hangs). Resolving the
        /// target's mach port inside the window takes that same lock.
        func test_noDeadlock_victimHammersPthreadCreateJoin() throws {
            try XCTSkipIfSanitizing("thread suspension + KSCrash walk are unsafe under sanitizer instrumentation")

            try assertNoDeadlockWhileVictimHammers("pthread_create + pthread_join") {
                var child: pthread_t?
                guard pthread_create(&child, nil, { _ in nil }, nil) == 0, let child else { return false }
                return pthread_join(child, nil) == 0
            }
        }

        /// Querying *another* thread's handle also validates it under the thread-list lock.
        func test_noDeadlock_victimHammersPthreadMachThreadNp() throws {
            try XCTSkipIfSanitizing("thread suspension + KSCrash walk are unsafe under sanitizer instrumentation")

            let ready = DispatchSemaphore(value: 0)
            let mayExit = DispatchSemaphore(value: 0)
            let finished = DispatchSemaphore(value: 0)
            let box = PThreadBox()

            // A parked thread whose handle the victim keeps querying.
            let other = Thread {
                box.value = pthread_self()
                ready.signal()
                mayExit.wait()
                finished.signal()
            }
            other.name = "emb.deadlock.parked"
            other.start()
            ready.wait()
            defer {
                mayExit.signal()
                finished.wait()
            }

            let otherThread = try XCTUnwrap(box.value, "parked thread did not publish its pthread_t")

            try assertNoDeadlockWhileVictimHammers("pthread_mach_thread_np(otherThread)") {
                pthread_mach_thread_np(otherThread) != MACH_PORT_NULL
            }
        }
    }

#endif
