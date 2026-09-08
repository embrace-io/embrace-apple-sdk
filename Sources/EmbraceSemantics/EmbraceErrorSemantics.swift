//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

/// Values shared by every Embrace error type that bridges to `NSError`.
///
/// These are kept in a single place so all Embrace errors report the same domain and the same
/// fallback description when they carry no message of their own.
enum EmbraceErrorSemantics {
    /// The `NSError` domain used by every Embrace error.
    static let domain = "Embrace"

    /// Used as `localizedDescription` when an error provides no description.
    static let fallbackDescription = "No Matching Error"
}
