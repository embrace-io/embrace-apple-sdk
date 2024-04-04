//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

@objc public enum LogSeverity: Int, Codable {
    case info = 9
    case warn = 13
    case error = 17

    /// The value provided is compliant with what SeverityText is for OTel
    /// More info: https://opentelemetry.io/docs/specs/otel/logs/data-model/
    public var text: String {
        switch self {
        case .info: "INFO"
        case .warn: "WARN"
        case .error: "ERROR"
        }
    }

    /// The value provided is compliant with what SeverityNumber is for OTel
    /// More info: https://opentelemetry.io/docs/specs/otel/logs/data-model/
    public var number: Int {
        return self.rawValue
    }
}

extension LogSeverity: CustomStringConvertible {
    public var description: String {
        text
    }
}
