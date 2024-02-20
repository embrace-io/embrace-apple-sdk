//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public enum MetadataError: Error, Equatable {
    case invalidKey(_ description: String)
    case invalidSession(_ description: String)
    case limitReached(_ description: String)
}

extension MetadataError: LocalizedError, CustomNSError {

    public static var errorDomain: String {
        return "Embrace"
    }

    public var errorCode: Int {
        switch self {
        case .invalidKey:
            return -1
        case .invalidSession:
            return -2
        case .limitReached:
            return -3
        }
    }

    public var errorDescription: String? {
        switch self {
        case .invalidKey(let description):
            return description
        case .invalidSession(let description):
            return description
        case .limitReached(let description):
            return description
        }
    }

    public var localizedDescription: String {
        return self.errorDescription ?? "No Matching Error"
    }
}
