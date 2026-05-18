//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public struct UserSessionSemantics {
    /// Default maximum duration of a user session, in seconds (12 hours).
    public static let defaultMaxDurationSeconds: TimeInterval = 12 * 3600

    /// Default inactivity timeout for a user session, in seconds (30 minutes).
    public static let defaultInactivityTimeoutSeconds: TimeInterval = 30 * 60
}
