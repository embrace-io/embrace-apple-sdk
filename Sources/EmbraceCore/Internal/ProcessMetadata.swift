//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

enum ProcessMetadata {}

extension ProcessMetadata {

    /// The Date at which this process started
    /// Retrieved via `sysctl` and `kinfo_proc.kp_proc`
    static var startTime: Date? = {
        // Allocate memory
        let infoPointer = UnsafeMutablePointer<kinfo_proc>.allocate(capacity: 1)
        infoPointer.initialize(to: kinfo_proc())
        defer {
            infoPointer.deallocate()
        }

        let pid: pid_t = ProcessInfo.processInfo.processIdentifier
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]

        // Call sysctl with infoPointer and check the result
        var size = MemoryLayout<kinfo_proc>.stride
        let retval = sysctl(&mib, UInt32(mib.count), infoPointer, &size, nil, 0)

        if retval != 0 {
            Embrace.logger.error("Error: \(#file) \(#function) \(#line) - sysctl failed with errno=\(errno)")
            return nil
        }

        let timeval = infoPointer.pointee.kp_proc.p_starttime
        let value = Double(timeval.tv_sec) + (Double(timeval.tv_usec) / 1000000.0)

        return Date(timeIntervalSince1970: value)
    }()

    /// The TimeInterval since this process was created
    /// - Parameter date: A reference date to compare. Defaults to the current date
    /// - Returns: Returns the time interval difference between the reference date and the ``ProcessMetadata.startTime``.
    ///             This value could be negative if the date passed in is before the process start time
    static func uptime(since date: Date = Date()) -> TimeInterval? {
        guard let startTime = startTime else {
            return nil
        }
        return date.timeIntervalSince(startTime)
    }

}
