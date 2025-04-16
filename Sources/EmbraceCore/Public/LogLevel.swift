//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceCommonInternal
#endif

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

    var severity: LogSeverity {
        switch self {
        case .trace: return LogSeverity.trace
        case .debug: return LogSeverity.debug
        case .info: return LogSeverity.info
        case .warning: return LogSeverity.warn
        default: return LogSeverity.error
        }
    }
}
