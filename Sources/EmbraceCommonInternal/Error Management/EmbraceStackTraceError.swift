//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public enum EmbraceStackTraceError: Error {
    case invalidFormat
    case frameIsTooLong
}

extension EmbraceStackTraceError: LocalizedError, CustomNSError {

    public static var errorDomain: String {
        return "Embrace"
    }

    public var errorCode: Int {
        switch self {
        case .invalidFormat:
            return -1
        case .frameIsTooLong:
            return -2
        }
    }

    public var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return """
                    Invalid stack trace format. Each frame should follow this format:
                    <index> <image> <memory address> <symbol> [ + <offset> ]
                    The "+ <offset>" part is optional.
                """
        case .frameIsTooLong:
            return "The stacktrace contains frames that are longer than 10.000 characters."
        }
    }

    public var localizedDescription: String {
        return self.errorDescription ?? "No Matching Error"
    }
}
