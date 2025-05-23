//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceBugsnagTools
#endif

public struct EmbraceBacktraceFrame: Codable {
    let address: UInt64
    let symbolAddress: UInt64
    let symbolName: String
    let imageUUID: String
    let imageName: String
    let imageSize: UInt64
    let imageOffset: UInt64
}
extension EmbraceBacktraceFrame: Sendable {}

public struct EmbraceBacktraceThread: Codable {
    let index: Int
    let name: String
    let frames: [EmbraceBacktraceFrame]
}
extension EmbraceBacktraceThread: Sendable {}

public struct EmbraceBacktrace: Codable {
    let timestamp: UInt64 // mono nanoseconds
    let threads: [EmbraceBacktraceThread]
    
    /// Call this early during startup so images are ready when we need them.
    static func bootstrap() {
        // can be called as many times as we want, only the first counts.
        // KSCrash does this as well so we might want to organize, but for
        // now this is ok.
        bsg_mach_headers_initialize()
    }
    
    /// Call this to take a stacktrace of the passed in thread.
    static func backtrace(of thread: pthread_t) -> EmbraceBacktrace {
        EmbraceBacktrace(
            timestamp: clock_gettime_nsec_np(CLOCK_UPTIME_RAW),
            threads: takeSnapshot(of: thread)
        )
    }
}
extension EmbraceBacktrace: Sendable {}
