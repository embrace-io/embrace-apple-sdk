//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public class NoopInternalLogger: InternalLogger {
    public func log(level: LogLevel, message: String, attributes: [String: String]) -> Bool {
        return false
    }

    public func log(level: LogLevel, message: String) -> Bool {
        return false
    }

    public func trace(_ message: String, attributes: [String: String]) -> Bool {
        return false
    }

    public func trace(_ message: String) -> Bool {
        return false
    }

    public func debug(_ message: String, attributes: [String: String]) -> Bool {
        return false
    }

    public func debug(_ message: String) -> Bool {
        return false
    }

    public func info(_ message: String, attributes: [String: String]) -> Bool {
        return false
    }

    public func info(_ message: String) -> Bool {
        return false
    }

    public func warning(_ message: String, attributes: [String: String]) -> Bool {
        return false
    }

    public func warning(_ message: String) -> Bool {
        return false
    }

    public func error(_ message: String, attributes: [String: String]) -> Bool {
        return false
    }

    public func error(_ message: String) -> Bool {
        return false
    }
}

extension InternalLogger where Self == NoopInternalLogger {
    public static var noop: InternalLogger { NoopInternalLogger() }
}
