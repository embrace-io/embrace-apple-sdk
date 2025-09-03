//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public enum EmbraceOTelError: Error, Equatable {
    case invalidSession
    case spanLimitReached
    case spanEventLimitReached(_ description: String)
    case spanLinkLimitReached(_ description: String)
    case spanAttributeLimitReached(_ description: String)
    case logLimitReached
}

extension EmbraceOTelError: LocalizedError, CustomNSError {

    public static var errorDomain: String {
        return "Embrace"
    }

    public var errorCode: Int {
        switch self {
        case .invalidSession: -1
        case .spanLimitReached: -2
        case .spanEventLimitReached: -3
        case .spanLinkLimitReached: -4
        case .spanAttributeLimitReached: -5
        case .logLimitReached: -6
        }
    }

    public var errorDescription: String? {
        switch self {
        case .invalidSession: "No active Embrace session!"
        case .spanLimitReached: "Span limit reached for the current Embrace session!"
        case .spanEventLimitReached(let description): description
        case .spanLinkLimitReached(let description): description
        case .spanAttributeLimitReached(let description): description
        case .logLimitReached: "Log limit reached for the current Embrace session!"
        }
    }

    public var localizedDescription: String {
        return self.errorDescription ?? "No Matching Error"
    }
}
