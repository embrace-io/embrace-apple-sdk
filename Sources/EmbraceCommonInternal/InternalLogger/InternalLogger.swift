//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
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

    public var severity: LogSeverity {
        switch self {
        case .trace: return LogSeverity.trace
        case .debug: return LogSeverity.debug
        case .info: return LogSeverity.info
        case .warning: return LogSeverity.warn
        default: return LogSeverity.error
        }
    }
}

@objc public protocol InternalLogger: AnyObject {
    @discardableResult @objc func log(level: LogLevel, message: String, attributes: [String: String]) -> Bool
    @discardableResult @objc func log(level: LogLevel, message: String) -> Bool

    @discardableResult @objc func trace(_ message: String, attributes: [String: String]) -> Bool
    @discardableResult @objc func trace(_ message: String) -> Bool

    @discardableResult @objc func debug(_ message: String, attributes: [String: String]) -> Bool
    @discardableResult @objc func debug(_ message: String) -> Bool

    @discardableResult @objc func info(_ message: String, attributes: [String: String]) -> Bool
    @discardableResult @objc func info(_ message: String) -> Bool

    @discardableResult @objc func warning(_ message: String, attributes: [String: String]) -> Bool
    @discardableResult @objc func warning(_ message: String) -> Bool

    @discardableResult @objc func error(_ message: String, attributes: [String: String]) -> Bool
    @discardableResult @objc func error(_ message: String) -> Bool
}
