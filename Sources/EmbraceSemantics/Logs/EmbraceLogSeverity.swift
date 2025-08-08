//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

public enum EmbraceLogSeverity: Int, Codable {
    case trace = 1
    case debug = 5
    case info = 9
    case warn = 13
    case error = 17
    case fatal = 21
    case critical = 24

    /// The value provided is compliant with what SeverityText is for OTel
    /// More info: https://opentelemetry.io/docs/specs/otel/logs/data-model/
    public var text: String {
        switch self {
        case .trace: "TRACE"
        case .debug: "DEBUG"
        case .info: "INFO"
        case .warn: "WARN"
        case .error: "ERROR"
        default: "FATAL"
        }
    }

    /// The value provided is compliant with what SeverityNumber is for OTel
    /// More info: https://opentelemetry.io/docs/specs/otel/logs/data-model/
    public var number: Int {
        return self.rawValue
    }
}

extension EmbraceLogSeverity: CustomStringConvertible {
    public var description: String {
        text
    }
}
