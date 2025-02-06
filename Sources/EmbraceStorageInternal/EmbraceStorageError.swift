//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public enum EmbraceStorageError: Error, Equatable {
    case cannotUpsertSpan(spanName: String, message: String)
    // TODO: Add missing errors in here
}

extension EmbraceStorageError: LocalizedError, CustomNSError {
    public static var errorDomain: String {
        return "Embrace"
    }

    public var errorCode: Int {
        switch self {
        case .cannotUpsertSpan:
            return -1
        }
    }

    public var errorDescription: String? {
        switch self {
        case .cannotUpsertSpan(let spanName, let message):
            return "Failed upsertSpan `\(spanName)`: \(message)"
        }
    }

    public var localizedDescription: String {
        return self.errorDescription ?? "No Matching Error"
    }
}
