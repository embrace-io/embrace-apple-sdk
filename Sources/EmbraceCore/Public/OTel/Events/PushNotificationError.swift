//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

package enum PushNotificationError: Error, Equatable {
    case invalidPayload(_ description: String)
}

extension PushNotificationError: LocalizedError, CustomNSError {

    package static var errorDomain: String {
        return "Embrace"
    }

    package var errorCode: Int {
        switch self {
        case .invalidPayload:
            return -1
        }
    }

    package var errorDescription: String? {
        switch self {
        case .invalidPayload(let description):
            return description
        }
    }

    package var localizedDescription: String {
        return self.errorDescription ?? "No Matching Error"
    }
}
