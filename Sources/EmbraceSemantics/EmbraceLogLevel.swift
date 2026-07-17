//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// Verbosity levels for the Embrace SDK's console logs, ordered by increasing severity.
public enum EmbraceLogLevel: Int {
    /// Disables all console logs.
    case none
    /// Fine-grained tracing messages.
    case trace
    /// Debugging messages.
    case debug
    /// Informational messages.
    case info
    /// Warnings about unexpected but recoverable situations.
    case warning
    /// Errors that prevented an operation from completing.
    case error
    /// Critical failures.
    case critical

    #if DEBUG
        public static let `default`: EmbraceLogLevel = .debug
    #else
        public static let `default`: EmbraceLogLevel = .error
    #endif

    package var severity: EmbraceLogSeverity {
        switch self {
        case .trace: return EmbraceLogSeverity.trace
        case .debug: return EmbraceLogSeverity.debug
        case .info: return EmbraceLogSeverity.info
        case .warning: return EmbraceLogSeverity.warn
        case .error: return EmbraceLogSeverity.error
        default: return EmbraceLogSeverity.critical
        }
    }
}
