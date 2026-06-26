//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceKSCrashBacktraceSupport
    import EmbraceSemantics
#endif

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

        guard let result = KSCrashBacktracing().resolve(address: UInt(address)) else {
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

    static func takeSnapshot(of thread: pthread_t, threadIndex: Int = 0) -> [EmbraceBacktraceThread] {
        let snap = _takeSnapshot(of: thread, threadIndex: threadIndex)
        return snap
    }

    static func _takeSnapshot(of thread: pthread_t, threadIndex: Int = 0) -> [EmbraceBacktraceThread] {

        // get the mach thread to take the snapshot of
        let machThread = pthread_mach_thread_np(thread)
        let canSuspend = pthread_self() != thread

        // suspend thread if not the current thread.
        if canSuspend {
            guard emb_thread_suspend(machThread) == KERN_SUCCESS else {
                Embrace.logger.warning("[EmbraceBacktrace] error suspending thread")
                return []
            }
        }

        // Get the actual snapshot,
        let backtraceAddresses = KSCrashBacktracing().backtrace(of: thread)

        // resume thread
        if canSuspend {
            emb_thread_resume(machThread)
        }

        // remove the entries that are part of the SDK,
        // get only the first N entries to not overload the system,
        // clean 'em up.
        let entries = 512
        let addresses =
            backtraceAddresses
            .dropFirst(5)
            .prefix(entries)
            .compactMap { $0 as UInt }

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
