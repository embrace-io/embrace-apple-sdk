//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceKSCrashBacktraceSupport
#endif

private class EmbraceThreadList {
    let task: mach_port_t
    let threads: thread_act_array_t?
    let threadCount: mach_msg_type_number_t

    init(task: mach_port_t = mach_task_self_) {
        self.task = task

        var threadList: thread_act_array_t?
        var threadCount: mach_msg_type_number_t = 0

        let result = task_threads(self.task, &threadList, &threadCount)
        if result == KERN_SUCCESS {
            self.threads = threadList
            self.threadCount = threadCount
        } else {
            self.threads = nil
            self.threadCount = 0
        }
    }

    deinit {
        if let threads {
            let deallocSize = vm_size_t(threadCount) * vm_size_t(MemoryLayout<thread_t>.size)
            vm_deallocate(task, vm_address_t(UInt(bitPattern: threads)), deallocSize)
        }
    }

    func withThreads(_ block: (_ thread: thread_act_t) -> Void) {
        guard let threads else {
            return
        }
        let current = pthread_mach_thread_np(pthread_self())
        for i in 0..<Int(threadCount) {
            if threads[i] == current {
                continue
            }
            block(threads[i])
        }
    }

    /// Suspends all threads except the current one
    func suspend() {
        #if !os(watchOS)
            withThreads {
                let err = thread_suspend($0)
                if err != KERN_SUCCESS {
                    Embrace.logger.warning("[THREAD.SUSPEND] err: \(err), \(String(cString: mach_error_string(err)))")
                }
            }
        #endif
    }

    /// Resumes all threads except the current one
    func resume() {
        #if !os(watchOS)
            withThreads {
                let err = thread_resume($0)
                if err != KERN_SUCCESS {
                    Embrace.logger.warning("[THREAD.RESUME] err: \(err), \(String(cString: mach_error_string(err)))")
                }
            }
        #endif
    }

    func indexOf(thread: pthread_t) -> Int {
        guard let threads else { return -1 }
        let machThread = pthread_mach_thread_np(thread)
        for index in 0..<Int(threadCount) {
            if threads[index] == machThread {
                return index
            }
        }
        return -1
    }
}

private var _symbolCache = SymbolCache()

internal class SymbolCache {
    struct Item {
        var accessDate: UInt64
        let frame: EmbraceBacktraceFrame
        let address: UInt64
    }
    let cache: EmbraceMutex<[UInt64: Item]> = EmbraceMutex([:])
    let limit: Int

    init(limit: Int = 4096) {
        self.limit = limit
    }

    func retrieve(_ address: UInt64) -> EmbraceBacktraceFrame? {
        return cache.withLock {
            $0[address]?.accessDate = clock_gettime_nsec_np(CLOCK_MONOTONIC)
            return $0[address]?.frame
        }
    }

    func store(_ frame: EmbraceBacktraceFrame, for address: UInt64) {
        cache.withLock {
            $0[address] = Item(
                accessDate: clock_gettime_nsec_np(CLOCK_MONOTONIC),
                frame: frame,
                address: address
            )

            // purge
            if $0.count > limit {
                let keysToRemove = $0.values.sorted { $0.accessDate < $1.accessDate }.prefix($0.count - limit).map(\.address)
                for key in keysToRemove {
                    $0.removeValue(forKey: key)
                    if $0.count <= limit {
                        break
                    }
                }
            }
        }
    }
}

extension EmbraceBacktraceThread.Callstack {
    func frames(symbolicated: Bool) -> [EmbraceBacktraceFrame] {

        var frames: [EmbraceBacktraceFrame] = []
        for index: Int in (0..<count) {
            let embFrame = EmbraceBacktraceFrame(withFramePointer: UInt64(addresses[index]))
            frames.append(
                symbolicated ? embFrame.symbolicated() : embFrame
            )
        }
        return frames
    }
}

extension EmbraceBacktraceFrame {

    init(withFramePointer address: UInt64) {
        self.address = address
        self.symbol = nil
        self.image = nil
    }

    fileprivate func symbolicated() -> EmbraceBacktraceFrame {
        guard image == nil else {
            return self
        }

        if let cached = _symbolCache.retrieve(address) {
            return cached
        }

        guard let result = Embrace.client?.options.symbolicator?.resolve(address: UInt(address)) else {
            return self
        }

        let symbolicatedFrame = EmbraceBacktraceFrame(
            address: UInt64(result.callInstruction),  // returnAddress - 1
            symbol: Symbol(
                address: result.symbolAddress,
                name: result.symbolName ?? ""
            ),
            image: result.imageName != nil
                ? Image(
                    uuid: result.imageUUID ?? "",
                    name: result.imageName.flatMap { $0 as NSString }?.lastPathComponent ?? "",
                    address: result.imageAddress,
                    size: result.imageSize
                ) : nil
        )

        _symbolCache.store(symbolicatedFrame, for: address)

        return symbolicatedFrame
    }
}

/// The IMP of `Backtracer.backtrace(of:into:capacity:)`. An `@objc` method's IMP takes the receiver
/// and `_cmd` ahead of the declared arguments. The receiver is a raw pointer rather than `AnyObject`
/// so calling it does no retain/release.
private typealias BacktraceIntoIMP =
    @convention(c) (
        UnsafeMutableRawPointer, Selector, pthread_t, UnsafeMutablePointer<FrameAddress>, Int
    ) -> Int

private let backtraceIntoSelector = #selector(Backtracer.backtrace(of:into:capacity:))

/// Resolves `backtracer`'s implementation of `backtrace(of:into:capacity:)` so it can be called
/// directly while a thread is suspended.
///
/// Must be called *before* `thread_suspend`: the lookup itself takes the ObjC runtime lock. The
/// lookup uses the receiver's dynamic class, so it sees the same implementation `objc_msgSend` would
/// (including subclass overrides and KVO / isa-swizzled classes).
///
/// Returns `nil` when the class has no such method, e.g. an `NSProxy` that relies on message
/// forwarding. Forwarding can't run in the window, so that backtracer can't walk a suspended thread.
private func backtraceIntoIMP(of backtracer: Backtracer) -> BacktraceIntoIMP? {
    guard let cls = object_getClass(backtracer),
        let method = class_getInstanceMethod(cls, backtraceIntoSelector)
    else {
        return nil
    }
    return unsafeBitCast(method_getImplementation(method), to: BacktraceIntoIMP.self)
}

extension EmbraceBacktrace {
    @discardableResult
    static private func emb_thread_suspend(_ thread: mach_port_t) -> kern_return_t {
        #if !os(watchOS)
            return thread_suspend(thread)
        #else
            return KERN_SUCCESS
        #endif
    }

    @discardableResult
    static private func emb_thread_resume(_ thread: mach_port_t) -> kern_return_t {
        #if !os(watchOS)
            return thread_resume(thread)
        #else
            return KERN_SUCCESS
        #endif
    }
}

extension EmbraceBacktrace {

    /// Number of Embrace capture-plumbing frames on top of a stack walked on the *current* thread
    /// (self-capture, `canSuspend == false`): the `Backtracer` call and the `_takeSnapshot` /
    /// `takeSnapshot` / `backtrace(of:threadIndex:)` wrappers above the caller. Dropping exactly
    /// these lands frame 0 on the code that asked for the backtrace.
    ///
    /// Self-capture is a live path: `LogController` walks the current thread for warn/error log
    /// stack traces (`backtrace(of: pthread_self())`). The skip is *not* applied when suspending a
    /// different thread, whose genuine top frame is already the code we want (skip 0).
    ///
    /// - Important: this is wrapper *depth*, not a semantic constant — correct only while the call
    ///   chain above is unchanged. Those wrappers are `@inline(never)` so the depth is identical at
    ///   every optimization level, which lets the Debug-only `BacktraceFrameSkipTests` pin it for
    ///   Release too. If a refactor changes the chain, that test fails and points here.
    static let selfCaptureFrameSkip = 5

    /// Upper bound on frames captured per snapshot: deep enough for real call stacks, capped so a
    /// runaway/recursive stack can't blow up capture cost or payload size.
    static let maxCapturedFrames = 512

    // `@inline(never)` here (and on `backtrace(of:threadIndex:)`) pins the self-capture wrapper depth
    // so `selfCaptureFrameSkip` holds at every optimization level; without it the optimizer could
    // collapse this forwarder in Release and shift the skip by one.
    @inline(never)
    static func takeSnapshot(of thread: pthread_t, threadIndex: Int = 0) -> [EmbraceBacktraceThread] {
        let snap = _takeSnapshot(of: thread, threadIndex: threadIndex)
        return snap
    }

    @inline(never)
    static func _takeSnapshot(of thread: pthread_t, threadIndex: Int = 0) -> [EmbraceBacktraceThread] {

        guard let backtracer = Embrace.client?.options.backtracer else {
            return []
        }

        // Resolve the concrete type before suspending. `Backtracer` is an `@objc` protocol, so a
        // call through the existential is an `objc_msgSend`, which on a cold method cache takes the
        // ObjC runtime lock. If the suspended thread holds that lock, the walk never returns and the
        // process deadlocks. Calling the concrete type is a vtable dispatch instead: no locks.
        // A custom `Backtracer` gets the same guarantee through `backtraceIntoIMP(of:)` below.
        let ksBacktracer = backtracer as? KSCrashBacktracing

        // get the mach thread to take the snapshot of
        let machThread = pthread_mach_thread_np(thread)
        let canSuspend = pthread_self() != thread

        // Drop the SDK's own capture frames (present only on self-capture; see `selfCaptureFrameSkip`).
        let sdkFrameSkip = canSuspend ? 0 : Self.selfCaptureFrameSkip
        let entries = Self.maxCapturedFrames

        let addresses: [UInt]
        if canSuspend {
            // A custom backtracer is called through its IMP, looked up here, outside the window,
            // where taking the runtime lock is harmless.
            let customIMP: BacktraceIntoIMP?
            if ksBacktracer != nil {
                customIMP = nil
            } else if let imp = backtraceIntoIMP(of: backtracer) {
                customIMP = imp
            } else {
                Embrace.logger.warning("[EmbraceBacktrace] backtracer does not implement backtrace(of:into:capacity:)")
                return []
            }
            // Passed unretained so no retain/release runs in the window; `backtracer` is kept alive
            // by this frame (and by `Embrace.Options`) until the walk returns.
            let receiver = Unmanaged.passUnretained(backtracer as AnyObject).toOpaque()
            defer { withExtendedLifetime(backtracer) {} }

            // Deadlock hazard: if the suspended thread holds the allocator lock, any `malloc` in the
            // suspend window hangs the process. So allocate the buffer before the suspend and do all
            // heap work (copy/slice) after the resume — only the alloc-free
            // `backtrace(of:into:capacity:)` runs in the window.
            let buffer = UnsafeMutablePointer<FrameAddress>.allocate(capacity: entries)
            defer { buffer.deallocate() }

            guard emb_thread_suspend(machThread) == KERN_SUCCESS else {
                Embrace.logger.warning("[EmbraceBacktrace] error suspending thread")
                return []
            }
            // ───── SUSPEND WINDOW: allocation-free / async-signal-safe only ─────
            #if DEBUG
                EmbraceBacktraceSuspendWindowProbe.willEnter?()
            #endif
            let count: Int
            if let ksBacktracer {
                count = ksBacktracer.backtrace(of: thread, into: buffer, capacity: entries)
            } else {
                // Custom `Backtracer`: a plain C call to the IMP resolved above. No `objc_msgSend`,
                // no method-cache lookup.
                count = customIMP?(receiver, backtraceIntoSelector, thread, buffer, entries) ?? 0
            }
            #if DEBUG
                EmbraceBacktraceSuspendWindowProbe.didExit?()
            #endif
            // ───── END SUSPEND WINDOW ─────
            emb_thread_resume(machThread)

            addresses =
                Array(UnsafeBufferPointer(start: buffer, count: max(0, count)))
                .dropFirst(sdkFrameSkip)
                .prefix(entries)
                .compactMap { $0 as UInt }
        } else {
            // Self-capture: nothing is suspended, so the allocating array API is safe (and required
            // for the on-main `pthread_self()` path, which KSCrash handles specially).
            addresses =
                backtracer.backtrace(of: thread)
                .dropFirst(sdkFrameSkip)
                .prefix(entries)
                .compactMap { $0 as UInt }
        }

        return [
            EmbraceBacktraceThread(
                index: threadIndex,
                callstack: EmbraceBacktraceThread.Callstack(
                    addresses: addresses,
                    count: addresses.count
                )
            )
        ]
    }
}

extension EmbraceBacktraceFrame {

    static let moduleNameKey = "m"
    static let modulePathKey = "p"
    static let moduleOffsetKey = "o"
    static let moduleUUIDKey = "u"
    static let instructionAddressKey = "a"
    static let symbolNameKey = "s"
    static let symbolOffsetKey = "so"

    /// Build up a dictionary of a frame as required by the Embrace SDK
    func asProcessedFrame() -> [String: Any]? {
        guard let image, let symbol else {
            return nil
        }
        return [
            Self.instructionAddressKey: String(format: "0x%016llx", address),
            Self.moduleNameKey: image.name,
            Self.moduleOffsetKey: address &- UInt64(image.address),
            Self.modulePathKey: image.name,
            Self.symbolNameKey: symbol.name,
            Self.symbolOffsetKey: symbol.address &- image.address,
            Self.moduleUUIDKey: image.uuid
        ]
    }
}

#if DEBUG
    /// Test-only seam bracketing the `_takeSnapshot` thread-suspend window. Both hooks are `nil` in
    /// normal use (a `nil`-check is the only cost, and they are stripped entirely from Release), so
    /// they add nothing to production. The suspend-window sentinel test sets them to mark exactly
    /// when the target thread is suspended, so it can prove the walk allocates nothing in-window.
    /// The hooks themselves MUST be allocation-free — they run inside the window.
    enum EmbraceBacktraceSuspendWindowProbe {
        static var willEnter: (() -> Void)?
        static var didExit: (() -> Void)?
    }
#endif
