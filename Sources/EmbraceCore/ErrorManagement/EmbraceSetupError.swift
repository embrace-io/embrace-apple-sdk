//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public enum EmbraceSetupError: Error, Equatable {
    case invalidAppId(_ description: String)
    case invalidAppGroupId(_ description: String)
    case invalidThread(_ description: String)
    case unableToInitialize(_ description: String)
}

// Allows bridging to NSError
extension EmbraceSetupError: LocalizedError, CustomNSError {

    public static var errorDomain: String {
        return "Embrace"
    }

    public var errorCode: Int {
        switch self {
        case .invalidAppGroupId:
            return -1
        case .invalidAppId:
            return -2
        case .invalidThread:
            return -3
        case .unableToInitialize:
            return -4
        }
    }

    public var errorDescription: String? {
        switch self {
        case .invalidAppGroupId(let description):
            return description
        case .invalidAppId(let description):
            return description
        case .invalidThread(let description):
            return description
        case .unableToInitialize(let description):
            return description
        }
    }

    public var localizedDescription: String {
        return self.errorDescription ?? "No Matching Error"
    }
}
