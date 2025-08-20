//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public struct EmbraceBacktraceFrame: Codable {
    public let address: UInt64

    public struct Symbol: Codable {
        public let address: UInt
        public let name: String
    }
    public let symbol: Symbol?

    public struct Image: Codable {
        public let uuid: String
        public let name: String
        public let address: UInt
        public let size: UInt64
    }
    public let image: Image?
}
extension EmbraceBacktraceFrame: Sendable {}
extension EmbraceBacktraceFrame.Symbol: Sendable {}
extension EmbraceBacktraceFrame.Image: Sendable {}

public struct EmbraceBacktraceThread: Codable {
    public let index: Int
    public func frames(symbolicated: Bool) -> [EmbraceBacktraceFrame] {
        callstack.frames(symbolicated: symbolicated)
    }

    internal struct Callstack: Codable {
        let addresses: [UInt]
        let count: Int
    }
    internal let callstack: Callstack
}
extension EmbraceBacktraceThread: Sendable {}
extension EmbraceBacktraceThread.Callstack: Sendable {}

public enum EmbraceBacktraceTimestampUnits: String, Codable {
    case nanoseconds
    case milliseconds
}
extension EmbraceBacktraceTimestampUnits: Sendable {}

public struct EmbraceBacktrace: Codable {
    public let timestampUnits: EmbraceBacktraceTimestampUnits
    public let timestamp: UInt64
    public let threads: [EmbraceBacktraceThread]

    /// Call this to take a stacktrace of the passed in thread.
    static func backtrace(of thread: pthread_t, suspendingThreads: Bool) -> EmbraceBacktrace {
        EmbraceBacktrace(
            timestampUnits: .nanoseconds,
            timestamp: clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW),
            threads: takeSnapshot(of: thread, suspendingThreads: suspendingThreads)
        )
    }
}
extension EmbraceBacktrace: Sendable {}

extension EmbraceBacktraceFrame {
    
    static let moduleNameKey = "m";
    static let modulePathKey = "p";
    static let moduleOffsetKey = "o";
    static let moduleUUIDKey = "u";
    static let instructionAddressKey = "a";
    static let symbolNameKey = "s";
    static let symbolOffsetKey = "so";
    
    func asProcessedFrame() -> [String: Any]? {
        guard let image, let symbol else {
            return nil
        }
        return [
            Self.instructionAddressKey: String(format: "0x%016llx", address),
            Self.moduleNameKey: image.name,
            Self.moduleOffsetKey: image.address,
            Self.modulePathKey: "/\(image.name ?? "")",
            Self.symbolNameKey: symbol.name,
            Self.symbolOffsetKey: symbol.address - image.address, //
            Self.moduleUUIDKey: image.uuid
        ]
    }
}
