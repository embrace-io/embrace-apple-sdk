//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public enum EmbraceOTelError: Error, Equatable {
    case invalidSession(_ description: String)
    case spanLimitReached(_ description: String)
    case spanEventLimitReached(_ description: String)
}

extension EmbraceOTelError: LocalizedError, CustomNSError {

    public static var errorDomain: String {
        return "Embrace"
    }

    public var errorCode: Int {
        switch self {
        case .invalidSession:
            return -1
        case .spanLimitReached:
            return -2
        case .spanEventLimitReached:
            return -3
        }
    }

    public var errorDescription: String? {
        switch self {
        case .invalidSession(let description):
            return description
        case .spanLimitReached(let description):
            return description
        case .spanEventLimitReached(let description):
            return description
        }
    }

    public var localizedDescription: String {
        return self.errorDescription ?? "No Matching Error"
    }
}
