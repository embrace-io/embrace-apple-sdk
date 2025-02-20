//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public enum EmbraceStackTraceError: Error {
    case invalidFormat
}

extension EmbraceStackTraceError: LocalizedError, CustomNSError {

    public static var errorDomain: String {
        return "Embrace"
    }

    public var errorCode: Int {
        switch self {
        case .invalidFormat:
            return -1
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
        }
    }

    public var localizedDescription: String {
        return self.errorDescription ?? "No Matching Error"
    }
}
