//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// Levels ordered by severity
@objc public enum LogLevel: Int {
    case none
    case trace
    case debug
    case info
    case warning
    case error

    #if DEBUG
    public static let `default`: LogLevel = .debug
    #else
    public static let `default`: LogLevel = .error
    #endif
}

/// Class in charge of filtering and printing logs to the console
public class ConsoleLog {
    static public let shared = ConsoleLog()
    private init() { }

    #if DEBUG
    public var level: LogLevel = .debug
    #else
    public var level: LogLevel = .error
    #endif

    @discardableResult
    public func log(level: LogLevel, message: String, args: CVarArg...) -> Bool {
        guard self.level != .none && self.level.rawValue <= level.rawValue else {
            return false
        }

        print(String(format: message, args))
        return true
    }

    @discardableResult
    public static func trace(_ message: String, _ args: CVarArg...) -> Bool {
        shared.log(level: .trace, message: message, args: args)
    }

    @discardableResult
    public static func debug(_ message: String, _ args: CVarArg...) -> Bool {
        shared.log(level: .debug, message: message, args: args)
    }

    @discardableResult
    public static func info(_ message: String, _ args: CVarArg...) -> Bool {
        shared.log(level: .info, message: message, args: args)
    }

    @discardableResult
    public static func warning(_ message: String, _ args: CVarArg...) -> Bool {
        shared.log(level: .warning, message: message, args: args)
    }

    @discardableResult
    public static func error(_ message: String, _ args: CVarArg...) -> Bool {
        shared.log(level: .error, message: message, args: args)
    }
}
