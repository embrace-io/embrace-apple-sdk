//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public struct EmbraceBacktraceFrame: Codable {
    public let address: UInt64
    public let symbolAddress: UInt64
    public let symbolName: String
    public let imageUUID: String
    public let imageName: String
    public let imageSize: UInt64
    public let imageOffset: UInt64
}
extension EmbraceBacktraceFrame: Sendable {}

public struct EmbraceBacktraceThread: Codable {
    public let index: Int
    public let name: String
    public let frames: [EmbraceBacktraceFrame]
}
extension EmbraceBacktraceThread: Sendable {}

public struct EmbraceBacktrace: Codable {
    public let timestampUnits: String = "nanoseconds"
    public let timestamp: UInt64
    public let symbolicated: Bool
    public let threads: [EmbraceBacktraceThread]

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
