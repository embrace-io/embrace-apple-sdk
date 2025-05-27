//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceBugsnagTools
import EmbraceCommonInternal
#endif

#if !EMBRACE_COCOAPOD_BUILDING_SDK
import KSCrashDemangleFilter
#else
import KSCrash
#endif

private extension pthread_t {
    var name: String {
        var name = [CChar](repeating: 0, count: 64)
        let result = pthread_getname_np(self, &name, name.count)
        guard result == 0 else {
            return ""
        }
        return String(cString: name)
    }
}

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

extension EmbraceBacktraceFrame {
    
    init(withFramePointer address: UInt64) {
        self.address = address
        self.symbolAddress = 0
        self.symbolName = ""
        self.imageUUID = ""
        self.imageName = ""
        self.imageSize = 0
        self.imageOffset = 0
    }
    
    internal func symbolicated() -> EmbraceBacktraceFrame {
        guard imageUUID.isEmpty else { return self }
        
        if let cached = _symbolCache.withLock({ $0[address] }) {
            return cached
        }
        
        // there's an atomic check so this isn't expensive except for the first time
        bsg_mach_headers_initialize()
        
        var result: bsg_symbolicate_result = bsg_symbolicate_result()
        bsg_symbolicate(UInt(address), &result)
        
        let imageUUID: String
        let imageName: String
        let imageSize: UInt64
        let imageOffset: UInt64
        let success: Bool
        
        if let img = result.image {
            let ptr = img.pointee
            imageUUID = NSUUID(uuidBytes: ptr.uuid).uuidString
            imageName = NSString(utf8String: ptr.name)?.lastPathComponent ?? ""
            imageSize = ptr.imageSize
            imageOffset = UInt64(address) - ptr.imageVmAddr
            success = true
        } else {
            imageUUID = ""
            imageName = ""
            imageSize = 0
            imageOffset = 0
            success = false
        }
        
        let symbolName: String
        if success, let funcName = result.function_name {
            symbolName = backtraceDemangle(String(cString: funcName))
        } else {
            symbolName = ""
        }
        
        let symbolicatedFrame = EmbraceBacktraceFrame(
            address: UInt64(address),
            symbolAddress: UInt64(result.function_address),
            symbolName: symbolName,
            imageUUID: imageUUID,
            imageName: imageName,
            imageSize: imageSize,
            imageOffset: imageOffset
        )
        
        if success {
            _symbolCache.withLock { $0[address] = symbolicatedFrame }
        }
        
        return symbolicatedFrame
    }
}

//let currentThread = pthread_mach_thread_np(pthread_self())
//let snappingThread = pthread_mach_thread_np(thread)

internal extension EmbraceBacktrace {
    
    // This does a few things.
    // 1- suspends all threads except the current one.
    // 2- gets the index of the thread we want a backtrace of.
    // 3- sets up deferal of resuming all threads and releasing task thread memory.
    // 4- takes a backtrace and symbolicates it (or simply gets the images if not available).
    static func takeSnapshot(of thread: pthread_t) -> [EmbraceBacktraceThread] {
        
        let threadList = EmbraceThreadList()
        
        threadList.suspend()
        defer { threadList.resume() }
        
        let snapThread = pthread_mach_thread_np(thread)
        
        // now take the snapshot
        let entries = 512
        var addresses: [UInt] = Array(repeating: 0, count: 512)
        
        let frameCount = bsg_ksbt_backtraceThread(snapThread, &addresses, Int32(entries))
        
        var frames: [EmbraceBacktraceFrame] = []
        for index: Int in (0..<Int(frameCount)) {
            frames.insert(
                EmbraceBacktraceFrame(withFramePointer: UInt64(addresses[index])),
                at: 0
            )
        }

        return [
            EmbraceBacktraceThread(
                index: threadList.indexOf(thread: thread),
                name: thread.name,
                frames: frames
            )
        ]
    }
}

/*
@_silgen_name("swift_demangle_getSimplifiedDemangledName")
func _stdlib_swift_demangle_getSimplifiedDemangledName(
    _ MangledName: UnsafePointer<CChar>,
    _ OutputBuffer: UnsafeMutablePointer<CChar>,
    _ Length: Int
) -> Int

func backtraceSimplifiedSwiftDemangled(_ mangled: String) -> String {
    let bufferSize = 512
    var outputBuffer = [CChar](repeating: 0, count: bufferSize)
    
    return mangled.withCString { mangledPtr in
        let resultLen = _stdlib_swift_demangle_getSimplifiedDemangledName(
            mangledPtr,
            &outputBuffer,
            bufferSize
        )
        
        if resultLen > 0 && resultLen < bufferSize {
            return String(cString: outputBuffer)
        } else {
            return mangled
        }
    }
}
*/

var _data: [String: [String: String]] = [:]

func backtraceDemangle(_ symbol: String) -> String {

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

