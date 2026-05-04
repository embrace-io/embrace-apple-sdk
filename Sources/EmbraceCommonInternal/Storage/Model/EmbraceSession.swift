//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

package protocol EmbraceSession {
    var id: EmbraceIdentifier { get }
    var processId: EmbraceIdentifier { get }
    var state: SessionState { get }
    var traceId: String { get }
    var spanId: String { get }
    var startTime: Date { get }
    var endTime: Date? { get }
    var lastHeartbeatTime: Date { get }
    var crashReportId: String? { get }
    var coldStart: Bool { get }
    var cleanExit: Bool { get }
    var appTerminated: Bool { get }

    /// User-session number — repurposed in v7. All parts of the same user session share this value.
    /// Increments on user-session creation rather than per-part. Emitted on the wire as `emb.user_session_number`.
    var sessionNumber: EMBInt { get }

    // MARK: - User-session columns
    // The following fields are duplicated across every part record of the same user session.
    // `nil` (or `0` for `userSessionPartIndex`) on pre-upgrade rows — treated as "no active user session" by the controller.

    /// UUID of the owning user session.
    var userSessionId: EmbraceIdentifier? { get }

    /// Wall-clock start time of the owning user session. Same value across all parts of the same user session.
    var userSessionStartTime: Date? { get }

    /// Maximum duration (seconds) for the owning user session — config snapshot taken at user-session creation.
    var userSessionMaxDuration: TimeInterval? { get }

    /// Inactivity timeout (seconds) for the owning user session — config snapshot taken at user-session creation.
    var userSessionInactivityTimeout: TimeInterval? { get }

    /// Most recent foreground-part end time within the owning user session.
    /// Updated on every part record that ends a foreground part — the latest part record reflects the most recent value.
    var userSessionLastForegroundEnd: Date? { get }

    /// 1-indexed position of this part within its user session.
    var userSessionPartIndex: EMBInt { get }

    /// Termination reason — set only on the **last** part of a terminated user session.
    /// Drives `emb.user_session_termination_reason` and `emb.is_final_session_part = 1`.
    var userSessionEndReason: String? { get }
}
