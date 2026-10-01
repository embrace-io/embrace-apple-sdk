//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

// Thread suspension is unavailable on watchOS and the hang feature is gated out of macOS, so the
// suspend-window path these tests exercise only exists elsewhere.
#if !os(watchOS) && !os(macOS)

    import Foundation
    import ObjectiveC
    import TestSupport
    import XCTest

    #if !EMBRACE_COCOAPOD_BUILDING_SDK
        import EmbraceCommonInternal
    #endif

    @testable import EmbraceCore

    /// First frame each stub writes, naming which method the SDK called. Chosen so they can't come
    /// from a real walk. The second frame is the thread argument the method received.
    private let pthreadVariantTag: FrameAddress = 0xD1D1_0001
    private let machThreadVariantTag: FrameAddress = 0xD1D1_0002
    private let overriddenPthreadVariantTag: FrameAddress = 0xD1D1_0003

    /// The frame the replacement implementation writes when it is reached through `objc_msgSend`.
    private let dispatchedFrame: FrameAddress = 0xBAD0_0001

    /// A customer-style `Backtracer` that predates `backtrace(ofMachThread:into:capacity:)`. It is
    /// not `KSCrashBacktracing`, so the SDK reaches it through the custom-backtracer path.
    private final class PThreadOnlyBacktracer: Backtracer {
        func backtrace(of thread: pthread_t) -> [FrameAddress] { [] }

        func backtrace(
            of thread: pthread_t,
            into buffer: UnsafeMutablePointer<FrameAddress>,
            capacity: Int
        ) -> Int {
            guard capacity >= 2 else { return 0 }
            buffer[0] = pthreadVariantTag
            buffer[1] = FrameAddress(bitPattern: thread)
            return 2
        }
    }

    /// A custom `Backtracer` that implements the mach-port variant too. It conforms directly rather
    /// than subclassing `KSCrashBacktracing`: a subclass would take the built-in path and never reach
    /// the custom-backtracer dispatch.
    private final class MachThreadBacktracer: Backtracer {
        func backtrace(of thread: pthread_t) -> [FrameAddress] { [] }

        func backtrace(
            of thread: pthread_t,
            into buffer: UnsafeMutablePointer<FrameAddress>,
            capacity: Int
        ) -> Int {
            guard capacity >= 2 else { return 0 }
            buffer[0] = pthreadVariantTag
            buffer[1] = FrameAddress(bitPattern: thread)
            return 2
        }

        func backtrace(
            ofMachThread thread: thread_t,
            into buffer: UnsafeMutablePointer<FrameAddress>,
            capacity: Int
        ) -> Int {
            guard capacity >= 2 else { return 0 }
            buffer[0] = machThreadVariantTag
            buffer[1] = FrameAddress(thread)
            return 2
        }
    }

    /// A custom `Backtracer` meant to be subclassed. It implements only the `pthread_t` variant.
    private class BaseBacktracer: Backtracer {
        func backtrace(of thread: pthread_t) -> [FrameAddress] { [] }

        func backtrace(
            of thread: pthread_t,
            into buffer: UnsafeMutablePointer<FrameAddress>,
            capacity: Int
        ) -> Int {
            guard capacity >= 2 else { return 0 }
            buffer[0] = pthreadVariantTag
            buffer[1] = FrameAddress(bitPattern: thread)
            return 2
        }
    }

    /// Overrides the base's `pthread_t` variant.
    private final class OverridingBacktracer: BaseBacktracer {
        override func backtrace(
            of thread: pthread_t,
            into buffer: UnsafeMutablePointer<FrameAddress>,
            capacity: Int
        ) -> Int {
            guard capacity >= 2 else { return 0 }
            buffer[0] = overriddenPthreadVariantTag
            buffer[1] = FrameAddress(bitPattern: thread)
            return 2
        }
    }

    /// Adds the mach-port variant, which the base doesn't implement.
    private final class MachThreadInSubclassBacktracer: BaseBacktracer {
        func backtrace(
            ofMachThread thread: thread_t,
            into buffer: UnsafeMutablePointer<FrameAddress>,
            capacity: Int
        ) -> Int {
            guard capacity >= 2 else { return 0 }
            buffer[0] = machThreadVariantTag
            buffer[1] = FrameAddress(thread)
            return 2
        }
    }

    /// Fills the whole buffer but reports one frame more than it holds, violating the contract.
    private final class OverreportingBacktracer: Backtracer {
        func backtrace(of thread: pthread_t) -> [FrameAddress] { [] }

        func backtrace(
            of thread: pthread_t,
            into buffer: UnsafeMutablePointer<FrameAddress>,
            capacity: Int
        ) -> Int {
            for i in 0..<capacity { buffer[i] = pthreadVariantTag }
            return capacity + 1
        }
    }

    /// Implements only the self-capture walk, standing in for a backtracer whose suspended-thread
    /// walks are reachable only through forwarding (e.g. an `NSProxy`). The self-capture walk is
    /// still needed: the SDK's error about the unresolvable backtracer is exported as a log, which
    /// captures the logging thread's stack through it.
    private final class SelfCaptureOnlyBacktracer: NSObject {
        @objc(backtraceOf:) func backtrace(of thread: pthread_t) -> [FrameAddress] { [] }
    }

    private final class PThreadBox {
        var value: pthread_t?
        var machPort: thread_t = 0
    }

    final class CustomBacktracerDispatchTests: XCTestCase {

        override func tearDown() {
            _ = try? Embrace.client?.stop()
            Embrace.client = nil
            super.tearDown()
        }

        private func startEmbrace(backtracer: Backtracer) throws {
            _ = try? Embrace.client?.stop()
            Embrace.client = nil
            let options = Embrace.Options(
                appId: "myApp",
                captureServices: [],
                crashReporter: nil,
                backtracer: backtracer,
                symbolicator: nil
            )
            try Embrace.setup(options: options).start()
        }

        /// Parks a background thread, walks it with the configured backtracer, and returns the
        /// frames along with the walked thread and its mach port. The port is resolved by the thread
        /// itself: the thread is released on return, so resolving it afterwards could race its exit.
        private func walkParkedThread() throws -> (frames: [UInt], thread: pthread_t, machPort: thread_t) {
            let ready = DispatchSemaphore(value: 0)
            let hold = DispatchSemaphore(value: 0)
            let box = PThreadBox()

            let thread = Thread {
                box.value = pthread_self()
                box.machPort = pthread_mach_thread_np(pthread_self())
                ready.signal()
                hold.wait()
            }
            thread.name = "emb.custombacktracer.parked"
            thread.start()
            ready.wait()
            defer { hold.signal() }

            let target = try XCTUnwrap(box.value, "parked thread did not publish its pthread_t")
            let frames = EmbraceBacktrace.backtrace(of: target, threadIndex: 0).threads.first?.callstack.addresses ?? []
            return (frames, target, box.machPort)
        }

        /// A backtracer without the mach-port variant still works: the direct IMP call passes the
        /// `pthread_t`, buffer and return value through correctly.
        func test_pthreadOnlyBacktracer_isCalledWithTheTargetThread() throws {
            try startEmbrace(backtracer: PThreadOnlyBacktracer())

            let walk = try walkParkedThread()

            XCTAssertEqual(walk.frames, [pthreadVariantTag, FrameAddress(bitPattern: walk.thread)])
        }

        /// When a backtracer implements the mach-port variant, the SDK calls it with the target's
        /// mach port and never calls the `pthread_t` variant.
        func test_machThreadBacktracer_isPreferredAndGetsTheTargetsMachPort() throws {
            try startEmbrace(backtracer: MachThreadBacktracer())

            let walk = try walkParkedThread()

            XCTAssertEqual(
                walk.frames,
                [machThreadVariantTag, FrameAddress(walk.machPort)]
            )
        }

        /// The SDK looks the walk up on the receiver's dynamic class, so a subclass override wins
        /// over the base implementation.
        func test_subclassOverride_isCalled() throws {
            try startEmbrace(backtracer: OverridingBacktracer())

            let walk = try walkParkedThread()

            XCTAssertEqual(walk.frames, [overriddenPthreadVariantTag, FrameAddress(bitPattern: walk.thread)])
        }

        /// A mach-port variant declared only in a subclass is still exposed to the runtime (Swift
        /// infers `@objc` for it through the inherited conformance), so the SDK finds and prefers it.
        func test_machThreadVariantDeclaredInSubclass_isPreferred() throws {
            try startEmbrace(backtracer: MachThreadInSubclassBacktracer())

            let walk = try walkParkedThread()

            XCTAssertEqual(walk.frames, [machThreadVariantTag, FrameAddress(walk.machPort)])
        }

        /// A count larger than the buffer is clamped rather than read past the buffer's end.
        ///
        /// The returned frames are capped either way (`.prefix` after the copy), so without the clamp
        /// this only fails under AddressSanitizer, which reports the over-read as a heap-buffer-overflow.
        func test_overreportedCount_isClampedToTheBuffer() throws {
            try startEmbrace(backtracer: OverreportingBacktracer())

            let frames = try walkParkedThread().frames

            XCTAssertEqual(frames.count, EmbraceBacktrace.maxCapturedFrames)
            XCTAssertTrue(frames.allSatisfy { $0 == pthreadVariantTag })
        }

        /// Objective-C backtracers implement the method by its selector, so renaming the Swift
        /// declaration would silently stop the SDK from finding theirs and fall back to the
        /// `pthread_t` variant. Pin the selector.
        func test_machThreadVariant_selectorIsStable() {
            XCTAssertEqual(
                NSStringFromSelector(#selector(Backtracer.backtrace(ofMachThread:into:capacity:))),
                "backtraceOfMachThread:into:capacity:"
            )
        }

        #if DEBUG
            /// Proves the call inside the suspend window does not go through `objc_msgSend`.
            ///
            /// Once the thread is suspended, the probe swaps the method's implementation. A dynamic
            /// dispatch would see the swap and call the replacement. The SDK calls the IMP it looked
            /// up before suspending, so it must still reach the original.
            func test_customBacktracer_isNotDispatchedInsideTheSuspendWindow() throws {
                let backtracer = MachThreadBacktracer()
                try startEmbrace(backtracer: backtracer)

                let selector = #selector(Backtracer.backtrace(ofMachThread:into:capacity:))
                let method = try XCTUnwrap(class_getInstanceMethod(object_getClass(backtracer), selector))
                let originalIMP = method_getImplementation(method)

                let replacement:
                    @convention(c) (
                        AnyObject, Selector, thread_t, UnsafeMutablePointer<FrameAddress>, Int
                    ) -> Int = { _, _, _, buffer, capacity in
                        guard capacity > 0 else { return 0 }
                        buffer[0] = dispatchedFrame
                        return 1
                    }
                let replacementIMP = unsafeBitCast(replacement, to: IMP.self)

                EmbraceBacktraceSuspendWindowProbe.willEnter = {
                    method_setImplementation(method, replacementIMP)
                }
                defer {
                    EmbraceBacktraceSuspendWindowProbe.willEnter = nil
                    method_setImplementation(method, originalIMP)
                }

                let frames = try walkParkedThread().frames

                XCTAssertFalse(
                    frames.contains(dispatchedFrame),
                    "The custom backtracer was reached through objc_msgSend inside the suspend window."
                )
                XCTAssertEqual(frames.first, machThreadVariantTag)
            }
        #endif

        /// A backtracer whose class implements neither suspended-thread walk (e.g. one that relies on
        /// forwarding) is skipped before the suspend rather than called in the window.
        func test_backtracerWithoutTheMethods_returnsNoFrames() throws {
            // The class lacks the required `backtrace(of:into:capacity:)`, so `unsafeBitCast` gets
            // it past the type checker.
            let object = SelfCaptureOnlyBacktracer()
            defer { withExtendedLifetime(object) {} }
            try startEmbrace(backtracer: unsafeBitCast(object, to: Backtracer.self))

            #if DEBUG
                var suspended = false
                EmbraceBacktraceSuspendWindowProbe.willEnter = { suspended = true }
                defer { EmbraceBacktraceSuspendWindowProbe.willEnter = nil }
            #endif

            XCTAssertEqual(try walkParkedThread().frames, [])
            #if DEBUG
                XCTAssertFalse(suspended, "an unresolvable backtracer must be skipped before the suspend")
            #endif
        }
    }

#endif
