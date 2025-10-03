//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceSemantics
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

    // This does a few things.
    // 1- suspends all threads except the current one.
    // 2- gets the index of the thread we want a backtrace of.
    // 3- sets up deferal of resuming all threads and releasing task thread memory.
    // 4- takes a backtrace and symbolicates it (or simply gets the images if not available).
    static func takeSnapshot(of thread: pthread_t, suspendingThreads: Bool) -> [EmbraceBacktraceThread] {
        let snap = _takeSnapshot(of: thread, suspendingThreads: suspendingThreads)
        return snap
    }

    static func _takeSnapshot(of thread: pthread_t, suspendingThreads: Bool) -> [EmbraceBacktraceThread] {

        let threadList = suspendingThreads ? EmbraceThreadList() : nil
        threadList?.suspend()
        defer {
            if suspendingThreads {
                threadList?.resume()
            }
        }

        // Get the actual snapshot,
        // remove the entries that are part of the SDK,
        // get only the first N entries to not overload the system,
        // clean 'em up.
        let entries = 512
        let addresses =
            Embrace.client?.options.backtracer?
            .backtrace(of: thread)
            .dropFirst(5)
            .prefix(entries)
            .compactMap { $0 as UInt } ?? []

        return [
            EmbraceBacktraceThread(
                index: threadList?.indexOf(thread: thread) ?? 0,
                callstack: EmbraceBacktraceThread.Callstack(
                    addresses: addresses,
                    count: addresses.count
                )
            )
        ]
    }
}

extension EmbraceBacktrace {

    static func takeSnapshotApple() -> [EmbraceBacktraceThread] {
        let snap = _takeSnapshotApple()
        return snap
    }

    static func _takeSnapshotApple() -> [EmbraceBacktraceThread] {

        // Get the actual snapshot,
        // remove the entries that are part of the SDK,
        // get only the first N entries to not overload the system,
        // clean 'em up.
        let entries = 512
        let addresses =
            Thread.callStackReturnAddresses
            .dropFirst(3)
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
