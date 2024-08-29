//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

/// Embrace specific error status for spans
public enum ErrorCode: String {
    /// Span ended in an expected, but less than optimal state
    case failure

    /// Span ended because user reverted intent
    case userAbandon

    /// Span ended in some other way
    case unknown
}
