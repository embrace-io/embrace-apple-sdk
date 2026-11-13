//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// Defaults for reporting slow calls to app callbacks.
public struct SlowCallbackSemantics {
    /// Default threshold, in seconds, above which a call to `spanParent(for:currentParentContext:)` is slow.
    public static let defaultNetworkSpanParentProviderThreshold: TimeInterval = 0.005
}
