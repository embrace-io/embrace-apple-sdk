//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceCore

public class MockLogger: InternalLogger {

    public var level: LogLevel = .debug

    public init(level: LogLevel = .none) {
        self.level = level
    }

    public func log(level: LogLevel, message: String, attributes: [String: String] = [:]) -> Bool {
        guard self.level != .none && self.level.rawValue <= level.rawValue else {
            return false
        }

        print(message)
        return true
    }

    @discardableResult public func trace(_ message: String, attributes: [String: String]) -> Bool {
        return log(level: .trace, message: message, attributes: attributes)
    }
    @discardableResult public func trace(_ message: String) -> Bool {
        return log(level: .trace, message: message)
    }

    @discardableResult public func debug(_ message: String, attributes: [String: String]) -> Bool {
        return log(level: .debug, message: message, attributes: attributes)
    }
    @discardableResult public func debug(_ message: String) -> Bool {
        return log(level: .debug, message: message)
    }

    @discardableResult public func info(_ message: String, attributes: [String: String]) -> Bool {
        return log(level: .info, message: message, attributes: attributes)
    }
    @discardableResult public func info(_ message: String) -> Bool {
        return log(level: .info, message: message)
    }

    @discardableResult public func warning(_ message: String, attributes: [String: String]) -> Bool {
        return log(level: .warning, message: message, attributes: attributes)
    }
    @discardableResult public func warning(_ message: String) -> Bool {
        return log(level: .warning, message: message)
    }

    @discardableResult public func error(_ message: String, attributes: [String: String]) -> Bool {
        return log(level: .error, message: message, attributes: attributes)
    }
    @discardableResult public func error(_ message: String) -> Bool {
        return log(level: .error, message: message)
    }

    public func startup(_ message: String, attributes: [String: String]) -> Bool {
        return log(level: .info, message: message, attributes: attributes)
    }
    public func startup(_ message: String) -> Bool {
        return log(level: .info, message: message)
    }

    public func critical(_ message: String, attributes: [String: String]) -> Bool {
        return log(level: .critical, message: message, attributes: attributes)
    }
    public func critical(_ message: String) -> Bool {
        return log(level: .critical, message: message)
    }
}
