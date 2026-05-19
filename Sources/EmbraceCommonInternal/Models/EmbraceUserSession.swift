//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

/// Reason a user session was terminated.
/// Stored as a `String?` on the **last** part of a terminated user session
/// (column `userSessionTerminationReason` on `SessionRecord`), and emitted on the wire
/// as the value of `emb.user_session_termination_reason`.
public enum TerminationReason: String {
    case maxDurationReached = "max_duration_reached"
    case inactivity
    case manual
    case clockAnomaly = "clock_anomaly"
    case crash
}
