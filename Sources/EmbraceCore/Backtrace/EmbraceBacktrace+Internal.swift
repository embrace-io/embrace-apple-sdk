//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceCommonInternal
#endif

#if !EMBRACE_COCOAPOD_BUILDING_SDK
import KSCrashDemangleFilter
import KSCrashRecordingCore
#else
import KSCrash
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
        withThreads {
            let err = thread_suspend($0)
            if err != KERN_SUCCESS {
                print("[THREAD.SUSPEND] err: \(err), \(String(cString: mach_error_string(err)))")
            }
        }
    }
    
    /// Resumes all threads except the current one
    func resume() {
        withThreads {
            let err = thread_resume($0)
            if err != KERN_SUCCESS {
                print("[THREAD.RESUME] err: \(err), \(String(cString: mach_error_string(err)))")
            }
        }
    }
    
    func  indexOf(thread: pthread_t) -> Int {
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

var _symbolCache: EmbraceMutex<[UInt64: EmbraceBacktraceFrame]> = EmbraceMutex([:])

extension EmbraceBacktraceThread.Callstack {
    func frames(symbolicated: Bool) -> [EmbraceBacktraceFrame] {
        
        // expensive, don't call on the main queue
        if symbolicated {
            dispatchPrecondition(condition: .notOnQueue(.main))
        }
        
        var frames: [EmbraceBacktraceFrame] = []
        for index: Int in (0..<count) {
            let embFrame = EmbraceBacktraceFrame(withFramePointer: UInt64(addresses[index]))
            frames.insert(
                symbolicated ? embFrame.symbolicated() : embFrame,
                at: 0
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
        
        if let cached = _symbolCache.withLock({ $0[address] }) {
            return cached
        }
        
        var result = SymbolInformation()
        guard symbolicate(address: UInt(address), result: &result) else {
            return self
        }
 
        let symbolName = backtraceDemangle(
            result.symbolName != nil ? String(cString: result.symbolName!) : nil
        )
        let imageName = result.imageName != nil ? NSString(utf8String: result.imageName!)?.lastPathComponent ?? nil : nil
        
        let symbolicatedFrame = EmbraceBacktraceFrame(
            address: UInt64(address),
            symbol: Symbol(
                address: UInt64(result.symbolAddress),
                name: symbolName
            ),
            image: imageName != nil ? Image(
                uuid: NSUUID(uuidBytes: result.imageUUID).uuidString,
                name: imageName!,
                address: result.imageAddress,
                size: result.imageSize
            ) : nil
        )
        
        _symbolCache.withLock { $0[address] = symbolicatedFrame }
        
        return symbolicatedFrame
    }
}

internal extension EmbraceBacktrace {
    
    // This does a few things.
    // 1- suspends all threads except the current one.
    // 2- gets the index of the thread we want a backtrace of.
    // 3- sets up deferal of resuming all threads and releasing task thread memory.
    // 4- takes a backtrace and symbolicates it (or simply gets the images if not available).
    static func takeSnapshot(of thread: pthread_t) -> [EmbraceBacktraceThread] {
        let pre = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
        let snap = _takeSnapshot(of: thread)
        let post = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
        let cost = Double(post-pre) / 1_000_000.0
        print("[COST] \(cost) ms, frames: \(snap.first?.callstack.count ?? 0)")
        return snap
    }
    
    static func _takeSnapshot(of thread: pthread_t) -> [EmbraceBacktraceThread] {
        
        let threadList = EmbraceThreadList()
        
        threadList.suspend()
        defer { threadList.resume() }

        let entries = 512
        var addresses: [UInt] = Array(repeating: 0, count: 512)
        let frameCount = captureBacktrace(thread: thread, addresses: &addresses, count: Int32(entries))

        return [
            EmbraceBacktraceThread(
                index: threadList.indexOf(thread: thread),
                callstack: EmbraceBacktraceThread.Callstack(
                    addresses: addresses,
                    count: Int(frameCount)
                )
            )
        ]
    }
}

func backtraceDemangle(_ symbol: String?) -> String {
    
    guard let symbol else { return "<unknown>" }
    
    // try simplified for the UI
    let a2 = CrashReportFilterDemangle.demangledSwiftSymbol(symbol).trimmingCharacters(in: .whitespacesAndNewlines)
    if !a2.isEmpty {
        return a2
    }
    
    // full non-simplified demangle
    if let a3 = _swift_demangleImpl(symbol)?.trimmingCharacters(in: .whitespacesAndNewlines) {
        return a3
    }
    
    // cpp demangle
    let a4 = CrashReportFilterDemangle.demangledCppSymbol(symbol).trimmingCharacters(in: .whitespacesAndNewlines)
    if !a4.isEmpty {
        return a4
    }
    
    // return the original, likely ObjC or something
    return symbol
}

@_silgen_name("swift_demangle")
public func _stdlib_demangleImpl(
    mangledName: UnsafePointer<CChar>?,
    mangledNameLength: UInt,
    outputBuffer: UnsafeMutablePointer<CChar>?,
    outputBufferSize: UnsafeMutablePointer<UInt>?,
    flags: UInt32
) -> UnsafeMutablePointer<CChar>?

private func _swift_demangleImpl(_ symbol: String) -> String? {

    return symbol.utf8CString.withUnsafeBufferPointer { (mangledNameUTF8CStr) in
        let demangledNamePtr = _stdlib_demangleImpl(
            mangledName: mangledNameUTF8CStr.baseAddress,
            mangledNameLength: UInt(mangledNameUTF8CStr.count - 1),
            outputBuffer: nil,
            outputBufferSize: nil,
            flags: 0)
        
        guard let demangledNamePtr else {
            return nil
        }
        
        let demangledName = String(cString: demangledNamePtr)
        free(demangledNamePtr)
        return demangledName
    }
}

