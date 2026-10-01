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

    /// Base of the addresses `StubBacktracer` writes, chosen so they can't come from a real walk.
    private let stubFrameBase: FrameAddress = 0xD1D1_0000
    private let stubFrameCount = 3

    /// The address the replacement implementation writes when it is reached through `objc_msgSend`.
    private let dispatchedFrame: FrameAddress = 0xBAD0_0001

    /// A customer-style `Backtracer`. It is not `KSCrashBacktracing`, so the SDK reaches it through
    /// the custom-backtracer path.
    private final class StubBacktracer: Backtracer {
        func backtrace(of thread: pthread_t) -> [FrameAddress] { [] }

        func backtrace(
            of thread: pthread_t,
            into buffer: UnsafeMutablePointer<FrameAddress>,
            capacity: Int
        ) -> Int {
            let count = min(capacity, stubFrameCount)
            for index in 0..<count {
                buffer[index] = stubFrameBase + FrameAddress(index + 1)
            }
            return count
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

        /// Parks a background thread and walks it with the configured backtracer.
        private func walkParkedThread() throws -> [UInt] {
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
            return EmbraceBacktrace.backtrace(of: target, threadIndex: 0).threads.first?.callstack.addresses ?? []
        }

        /// The direct IMP call passes the arguments and return value through correctly.
        func test_customBacktracer_isCalledAndItsFramesAreReturned() throws {
            try startEmbrace(backtracer: StubBacktracer())

            XCTAssertEqual(
                try walkParkedThread(),
                (1...stubFrameCount).map { stubFrameBase + FrameAddress($0) }
            )
        }

        #if DEBUG
            /// Proves the call inside the suspend window does not go through `objc_msgSend`.
            ///
            /// Once the thread is suspended, the probe swaps the method's implementation. A dynamic
            /// dispatch would see the swap and call the replacement. The SDK calls the IMP it looked
            /// up before suspending, so it must still reach the original.
            func test_customBacktracer_isNotDispatchedInsideTheSuspendWindow() throws {
                let backtracer = StubBacktracer()
                try startEmbrace(backtracer: backtracer)

                let selector = #selector(Backtracer.backtrace(of:into:capacity:))
                let method = try XCTUnwrap(class_getInstanceMethod(object_getClass(backtracer), selector))
                let originalIMP = method_getImplementation(method)

                let replacement:
                    @convention(c) (
                        AnyObject, Selector, pthread_t, UnsafeMutablePointer<FrameAddress>, Int
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

                let addresses = try walkParkedThread()

                XCTAssertFalse(
                    addresses.contains(dispatchedFrame),
                    "The custom backtracer was reached through objc_msgSend inside the suspend window."
                )
                XCTAssertEqual(addresses.first, stubFrameBase + 1)
            }
        #endif

        /// A backtracer whose class doesn't implement the method (only reachable through forwarding)
        /// is skipped rather than called in the window.
        func test_backtracerWithoutTheMethod_returnsNoFrames() throws {
            // `NSObject` has no `backtrace(of:into:capacity:)`. The cast is the only way to get such
            // an object past the type checker, which is the point: it stands in for an `NSProxy`.
            let object = NSObject()
            defer { withExtendedLifetime(object) {} }
            try startEmbrace(backtracer: unsafeBitCast(object, to: Backtracer.self))

            XCTAssertEqual(try walkParkedThread(), [])
        }
    }

#endif
