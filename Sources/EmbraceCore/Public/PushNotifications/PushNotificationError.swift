//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public enum PushNotificationError: Error, Equatable {
    case invalidPayload(_ description: String)
}

extension PushNotificationError: LocalizedError, CustomNSError {

    public static var errorDomain: String {
        return "Embrace"
    }

    public var errorCode: Int {
        switch self {
        case .invalidPayload:
            return -1
        }
    }

    public var errorDescription: String? {
        switch self {
        case .invalidPayload(let description):
            return description
        }
    }

    public var localizedDescription: String {
        return self.errorDescription ?? "No Matching Error"
    }
}
