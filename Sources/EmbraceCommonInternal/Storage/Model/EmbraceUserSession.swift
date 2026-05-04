//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

/// Reason a user session was terminated.
/// Stored as a `String?` on the **last** part of a terminated user session
/// (column `userSessionEndReason` on `SessionRecord`), and emitted on the wire
/// as the value of `emb.user_session_termination_reason`.
public enum TerminationReason: String {
    case maxDurationReached = "max_duration_reached"
    case inactivity
    case manual
    case clockAnomaly = "clock_anomaly"
    case crash
}

/// In-memory representation of a "user session" — a logical grouping of one or
/// more session parts (`EmbraceSession`) that share an identifier and config snapshot.
///
/// User sessions are NEVER persisted as their own entity. The fields below are
/// duplicated on every `SessionRecord` (the part record) that belongs to the same
/// user session. On cold start, the controller reconstructs a snapshot from the
/// latest `SessionRecord` and applies the spec §1.1 expiry rules.
public protocol EmbraceUserSession {
    var id: EmbraceIdentifier { get }
    var startTime: Date { get }
    var maxDuration: TimeInterval { get }
    var inactivityTimeout: TimeInterval { get }
    var lastForegroundPartEnd: Date? { get }
    var userSessionNumber: EMBInt { get }
    var partIndex: EMBInt { get }
    var endTime: Date? { get }
    var endReason: TerminationReason? { get }
}

/// Plain value-type `EmbraceUserSession` for in-memory use by `UserSessionController`.
public struct ImmutableUserSession: EmbraceUserSession {
    public let id: EmbraceIdentifier
    public let startTime: Date
    public let maxDuration: TimeInterval
    public let inactivityTimeout: TimeInterval
    public let lastForegroundPartEnd: Date?
    public let userSessionNumber: EMBInt
    public let partIndex: EMBInt
    public let endTime: Date?
    public let endReason: TerminationReason?

    public init(
        id: EmbraceIdentifier,
        startTime: Date,
        maxDuration: TimeInterval,
        inactivityTimeout: TimeInterval,
        lastForegroundPartEnd: Date? = nil,
        userSessionNumber: EMBInt,
        partIndex: EMBInt,
        endTime: Date? = nil,
        endReason: TerminationReason? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.maxDuration = maxDuration
        self.inactivityTimeout = inactivityTimeout
        self.lastForegroundPartEnd = lastForegroundPartEnd
        self.userSessionNumber = userSessionNumber
        self.partIndex = partIndex
        self.endTime = endTime
        self.endReason = endReason
    }
}
