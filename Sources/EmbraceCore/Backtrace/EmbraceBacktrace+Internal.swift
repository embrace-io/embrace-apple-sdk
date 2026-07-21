//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
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
                    uuid: NSUUID(uuidBytes: result.imageUUID).uuidString,
                    name: result.imageName.flatMap { $0 as NSString }?.lastPathComponent ?? "",
                    address: result.imageAddress,
                    size: result.imageSize
                ) : nil
        )

        _symbolCache.store(symbolicatedFrame, for: address)

        return symbolicatedFrame
    }
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

    /// Number of Embrace capture-plumbing frames sitting on top of a stack that was walked on the
    /// *current* thread (self-capture, i.e. `canSuspend == false`).
    ///
    /// When we walk our own thread the raw addresses begin inside the SDK: the
    /// `Thread.callStackReturnAddresses` read site, the `Backtracer` call, and the internal
    /// `_takeSnapshot` / `takeSnapshot` / `backtrace(of:threadIndex:)` wrappers — all above the code
    /// that actually asked for the backtrace. Dropping exactly these lands frame 0 on the caller.
    ///
    /// This is deliberately *not* applied when suspending and walking a **different** thread: that
    /// thread's genuine top frame is the code we want, with none of our wrappers above it (skip 0).
    ///
    /// - Important: This is wrapper *depth*, not a semantic constant — it only stays correct while
    ///   the call chain above is unchanged. The wrappers (`backtrace(of:threadIndex:)`,
    ///   `takeSnapshot`, `_takeSnapshot`) are marked `@inline(never)` precisely so this depth is
    ///   **identical at every optimization level**; that is what lets the Debug-only
    ///   `BacktraceFrameSkipTests` authoritatively pin it for Release too (the repo can't currently
    ///   run that suite in Release). If an internal refactor changes the chain, that test fails and
    ///   points here — update the constant and keep the `@inline(never)` wrappers intact.
    static let selfCaptureFrameSkip = 5

    /// Wrapper depth for the Apple/`Thread.callStackReturnAddresses` self-capture path
    /// (`_takeSnapshotApple`). Smaller than ``selfCaptureFrameSkip`` because that path has no
    /// `Backtracer` indirection on top. Pinned by the same test; see it for the drift caveat.
    static let appleSelfCaptureFrameSkip = 3

    // `@inline(never)` here (and on `backtrace(of:threadIndex:)`) is load-bearing: it pins the
    // self-capture wrapper depth so `selfCaptureFrameSkip` is identical at every optimization level.
    // Without it the optimizer could collapse this forwarder in Release, shifting the skip by one.
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

        // get the mach thread to take the snapshot of
        let machThread = pthread_mach_thread_np(thread)
        let canSuspend = pthread_self() != thread

        // Drop the SDK's own capture frames (present only on self-capture; see `selfCaptureFrameSkip`).
        let sdkFrameSkip = canSuspend ? 0 : Self.selfCaptureFrameSkip
        let entries = 512

        let addresses: [UInt]
        if canSuspend {
            // Suspending another thread to walk it is a #423-class deadlock hazard: if that thread
            // holds the allocator lock, any `malloc` inside the suspend window hangs the process. So
            // the buffer is allocated BEFORE the suspend and everything that touches the heap
            // (copy/slice) happens AFTER the resume; only the alloc-free `backtrace(of:into:capacity:)`
            // runs in the window.
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
            let count = backtracer.backtrace(of: thread, into: buffer, capacity: entries)
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

extension EmbraceBacktrace {

    // `@inline(never)` pins the Apple self-capture wrapper depth for `appleSelfCaptureFrameSkip`,
    // same rationale as `takeSnapshot`.
    @inline(never)
    static func takeSnapshotApple() -> [EmbraceBacktraceThread] {
        let snap = _takeSnapshotApple()
        return snap
    }

    @inline(never)
    static func _takeSnapshotApple() -> [EmbraceBacktraceThread] {

        // Get the actual snapshot,
        // remove the entries that are part of the SDK,
        // get only the first N entries to not overload the system,
        // clean 'em up.
        let entries = 512
        let addresses =
            Thread.callStackReturnAddresses
            .dropFirst(Self.appleSelfCaptureFrameSkip)
            .prefix(entries)
            .compactMap { $0 as? UInt }

        return [
            EmbraceBacktraceThread(
                index: 0,
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
