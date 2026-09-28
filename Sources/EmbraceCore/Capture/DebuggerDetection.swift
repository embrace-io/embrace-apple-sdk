//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Darwin
import Foundation

// Only the frame-timing services use this, and they're unavailable on watchOS and macOS.
#if !os(watchOS) && !os(macOS)

    /// Whether a debugger is attached to the current process.
    ///
    /// Frame-timing capture services disable themselves under a debugger, since breakpoints and stepping
    /// look like hangs and dropped frames.
    @inline(__always)
    func isDebuggerAttached() -> Bool {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var name: [Int32] = [
            CTL_KERN,
            KERN_PROC,
            KERN_PROC_PID,
            getpid()
        ]

        let result = name.withUnsafeMutableBufferPointer { namePtr -> Bool in
            return sysctl(namePtr.baseAddress, 4, &info, &size, nil, 0) == 0
        }

        guard result else { return false }
        return (info.kp_proc.p_flag & P_TRACED) != 0
    }

#endif
