//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
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
    /// than subclassing: a subclass method doesn't implicitly become `@objc` to satisfy an optional
    /// requirement, so the runtime wouldn't see it.
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

    private final class PThreadBox {
        var value: pthread_t?
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
        /// frames along with the walked thread.
        private func walkParkedThread() throws -> (frames: [UInt], thread: pthread_t) {
            let ready = DispatchSemaphore(value: 0)
            let hold = DispatchSemaphore(value: 0)
            let box = PThreadBox()

            let thread = Thread {
                box.value = pthread_self()
                ready.signal()
                hold.wait()
            }
            thread.name = "emb.custombacktracer.parked"
            thread.start()
            ready.wait()
            defer { hold.signal() }

            let target = try XCTUnwrap(box.value, "parked thread did not publish its pthread_t")
            let frames = EmbraceBacktrace.backtrace(of: target, threadIndex: 0).threads.first?.callstack.addresses ?? []
            return (frames, target)
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
                [machThreadVariantTag, FrameAddress(pthread_mach_thread_np(walk.thread))]
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

        /// A backtracer whose class implements neither method (only reachable through forwarding)
        /// is skipped rather than called in the window.
        func test_backtracerWithoutTheMethods_returnsNoFrames() throws {
            // `NSObject` implements neither walk. The cast is the only way to get such an object
            // past the type checker, which is the point: it stands in for an `NSProxy`.
            let object = NSObject()
            defer { withExtendedLifetime(object) {} }
            try startEmbrace(backtracer: unsafeBitCast(object, to: Backtracer.self))

            XCTAssertEqual(try walkParkedThread().frames, [])
        }
    }

#endif
