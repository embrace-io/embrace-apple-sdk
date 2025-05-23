//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceBugsnagTools
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
            thread_suspend($0)
        }
    }
    
    /// Resumes all threads except the current one
    func resume() {
        withThreads {
            thread_resume($0)
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
        
        // there's an atomic check so this isn't expensive except for the first time
        bsg_mach_headers_initialize()
        
        var result: bsg_symbolicate_result = bsg_symbolicate_result()
        bsg_symbolicate(UInt(address), &result)
        
        let imageUUID: String
        let imageName: String
        let imageSize: UInt64
        let imageOffset: UInt64
        
        if let img = result.image {
            let ptr = img.pointee
            imageUUID = NSUUID(uuidBytes: ptr.uuid).uuidString
            imageName = NSString(utf8String: ptr.name)?.lastPathComponent ?? ""
            imageSize = ptr.imageSize
            imageOffset = UInt64(address) - ptr.imageVmAddr
        } else {
            imageUUID = ""
            imageName = ""
            imageSize = 0
            imageOffset = 0
        }
        
        let symbolName: String
        if let funcName = result.function_name {
            symbolName = String(cString: funcName)
            // demangle here
        } else {
            symbolName = ""
        }
        
        return EmbraceBacktraceFrame(
            address: UInt64(address),
            symbolAddress: UInt64(result.function_address),
            symbolName: symbolName,
            imageUUID: imageUUID,
            imageName: imageName,
            imageSize: imageSize,
            imageOffset: imageOffset
        )
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
    //
    // There's a lot going on here and taking backtraces is a pretty perf heavy event.
    // Because of that, I'm trying to reuse everything I can, such as thread lists and such.
    // That is why the method is large. Otherwise i'd love it to be something likethe following:
    // ```swift
    // withSuspendedThreads {
    //    takeSnapshot()
    // }
    // ```
    // but alas, not today...
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

