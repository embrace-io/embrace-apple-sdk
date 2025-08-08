//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

/// Levels ordered by severity
@objc public enum LogLevel: Int {
    case none
    case trace
    case debug
    case info
    case warning
    case error
    case critical

    #if DEBUG
        public static let `default`: LogLevel = .debug
    #else
        public static let `default`: LogLevel = .error
    #endif

    var severity: EmbraceLogSeverity {
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
