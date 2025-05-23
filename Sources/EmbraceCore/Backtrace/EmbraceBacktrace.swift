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
    let timestampUnits: String = "nanoseconds"
    let timestamp: UInt64
    let symbolicated: Bool
    let threads: [EmbraceBacktraceThread]

    /// Call this to take a stacktrace of the passed in thread.
    static func backtrace(of thread: pthread_t) -> EmbraceBacktrace {
        EmbraceBacktrace(
            timestamp: clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW),
            symbolicated: false,
            threads: takeSnapshot(of: thread)
        )
    }
    
    func symbolicate() -> EmbraceBacktrace {
        guard symbolicated == false else {
            return self
        }
        
        return EmbraceBacktrace(
            timestamp: timestamp,
            symbolicated: true,
            threads: threads.map { thread in
                EmbraceBacktraceThread(
                    index: thread.index,
                    name: thread.name,
                    frames: thread.frames.map { frame in
                        frame.symbolicated()
                    }
                )
            }
        )
    }
}
extension EmbraceBacktrace: Sendable {}
