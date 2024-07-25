//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public enum EmbraceSwizzableError: Error, Equatable {
    case methodNotFound(selectorName: String, className: String)
}

// Allows bridging to NSError
extension EmbraceSwizzableError: LocalizedError, CustomNSError {

    public static var errorDomain: String {
        return "Embrace"
    }

    public var errorCode: Int {
        switch self {
        case .methodNotFound:
            return -1
        }
    }

    public var errorDescription: String? {
        switch self {
        case .methodNotFound(let selector, let className):
            return "No method for selector \(selector) in class \(className)"
        }
    }

    public var localizedDescription: String {
        return self.errorDescription ?? "No Matching Error"
    }
}
