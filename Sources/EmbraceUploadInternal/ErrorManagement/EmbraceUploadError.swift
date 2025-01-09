//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// Enum containing possible error codes
public enum EmbraceUploadErrorCode: Int {
    case invalidMetadata = 1000
    case invalidData = 1001
    case operationCancelled = 1002
    case attachmentUploadFailed = 1003
}

public enum EmbraceUploadError: Error, Equatable {
    case incorrectStatusCodeError(_ code: Int)
    case internalError(_ code: EmbraceUploadErrorCode)
}

// Allows bridging to NSError
extension EmbraceUploadError: LocalizedError, CustomNSError {

    public static var errorDomain: String {
        return "Embrace"
    }

    public var errorCode: Int {
        switch self {
        case .incorrectStatusCodeError(let code):
            return code
        case .internalError(let code):
            return code.rawValue
        }
    }

    public var errorDescription: String? {
        switch self {
        case .incorrectStatusCodeError(let code):
            return "Invalid status code received: \(code)"
        case .internalError(let code):
            return "Internal Error: \(code)"
        }
    }

    public var localizedDescription: String {
        return self.errorDescription ?? "No Matching Error"
    }
}
