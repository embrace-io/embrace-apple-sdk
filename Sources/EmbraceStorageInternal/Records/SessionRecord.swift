//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import CoreData
import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
    import EmbraceCommonInternal
#endif

/// Represents a session in the storage
@objc(SessionRecord)
public class SessionRecord: NSManagedObject {
    @NSManaged public var idRaw: String
    @NSManaged public var processIdRaw: String
    @NSManaged public var state: String
    @NSManaged public var traceId: String
    @NSManaged public var spanId: String
    @NSManaged public var startTime: Date
    @NSManaged public var endTime: Date?
    @NSManaged public var lastHeartbeatTime: Date
    @NSManaged public var crashReportId: String?

    /// Used to mark if the session is the first to occur during this process
    @NSManaged public var coldStart: Bool

    /// Used to mark the session ended in an expected manner
    @NSManaged public var cleanExit: Bool

    /// Used to mark the session that is active when the application was explicitly terminated by the user and/or system
    @NSManaged public var appTerminated: Bool

    /// User-session number. Repurposed in v7: now shared by all parts of the same user session
    /// and incremented on user-session creation, not per-part. Emitted on the wire as `emb.user_session_number`.
    @NSManaged public var sessionNumber: EMBInt

    // MARK: - User-session columns (v7)
    // All optional/nullable to keep the migration additive. Pre-upgrade rows carry `nil`
    // (and `0` for `userSessionPartIndex`) and are treated as "no active user session" on bootstrap.

    /// UUID of the owning user session. Same value across all parts of the same user session.
    @NSManaged public var userSessionIdRaw: String?

    /// Wall-clock start time of the owning user session.
    @NSManaged public var userSessionStartTime: Date?

    /// Max duration (seconds) for the owning user session — config snapshot taken at user-session creation.
    @NSManaged public var userSessionMaxDuration: NSNumber?

    /// Inactivity timeout (seconds) for the owning user session — config snapshot taken at user-session creation.
    @NSManaged public var userSessionInactivityTimeout: NSNumber?

    /// Most recent foreground-part end time within the owning user session.
    @NSManaged public var userSessionLastForegroundEnd: Date?

    /// 1-indexed position of this part within its user session. `0` for legacy rows.
    @NSManaged public var userSessionPartIndex: EMBInt

    /// Termination reason — set only on the last part of a terminated user session.
    @NSManaged public var userSessionEndReason: String?

    /// Note that this must be called within a `perform` on the CoreData context.
    class func create(
        context: NSManagedObjectContext,
        id: EmbraceIdentifier,
        processId: EmbraceIdentifier,
        state: SessionState,
        traceId: String,
        spanId: String,
        startTime: Date,
        endTime: Date? = nil,
        lastHeartbeatTime: Date? = nil,
        crashReportId: String? = nil,
        coldStart: Bool = false,
        cleanExit: Bool = false,
        appTerminated: Bool = false,
        sessionNumber: EMBInt = 0,
        userSessionId: EmbraceIdentifier? = nil,
        userSessionStartTime: Date? = nil,
        userSessionMaxDuration: TimeInterval? = nil,
        userSessionInactivityTimeout: TimeInterval? = nil,
        userSessionLastForegroundEnd: Date? = nil,
        userSessionPartIndex: EMBInt = 0,
        userSessionEndReason: String? = nil
    ) -> Bool {
        guard let description = NSEntityDescription.entity(forEntityName: Self.entityName, in: context) else {
            return false
        }

        let record = SessionRecord(entity: description, insertInto: context)
        record.idRaw = id.stringValue
        record.processIdRaw = processId.stringValue
        record.state = state.rawValue
        record.traceId = traceId
        record.spanId = spanId
        record.startTime = startTime
        record.endTime = endTime
        record.lastHeartbeatTime = lastHeartbeatTime ?? startTime
        record.crashReportId = crashReportId
        record.coldStart = coldStart
        record.cleanExit = cleanExit
        record.appTerminated = appTerminated
        record.sessionNumber = sessionNumber
        record.userSessionIdRaw = userSessionId?.stringValue
        record.userSessionStartTime = userSessionStartTime
        record.userSessionMaxDuration = userSessionMaxDuration.map { NSNumber(value: $0) }
        record.userSessionInactivityTimeout = userSessionInactivityTimeout.map { NSNumber(value: $0) }
        record.userSessionLastForegroundEnd = userSessionLastForegroundEnd
        record.userSessionPartIndex = userSessionPartIndex
        record.userSessionEndReason = userSessionEndReason

        return true
    }

    static func createFetchRequest() -> NSFetchRequest<SessionRecord> {
        return NSFetchRequest<SessionRecord>(entityName: entityName)
    }

    func toImmutable() -> EmbraceSession {
        return ImmutableSessionRecord(
            id: EmbraceIdentifier(stringValue: idRaw),
            processId: EmbraceIdentifier(stringValue: processIdRaw),
            state: SessionState(rawValue: state) ?? .unknown,
            traceId: traceId,
            spanId: spanId,
            startTime: startTime,
            endTime: endTime,
            lastHeartbeatTime: lastHeartbeatTime,
            crashReportId: crashReportId,
            coldStart: coldStart,
            cleanExit: cleanExit,
            appTerminated: appTerminated,
            sessionNumber: sessionNumber,
            userSessionId: userSessionIdRaw.map { EmbraceIdentifier(stringValue: $0) },
            userSessionStartTime: userSessionStartTime,
            userSessionMaxDuration: userSessionMaxDuration?.doubleValue,
            userSessionInactivityTimeout: userSessionInactivityTimeout?.doubleValue,
            userSessionLastForegroundEnd: userSessionLastForegroundEnd,
            userSessionPartIndex: userSessionPartIndex,
            userSessionEndReason: userSessionEndReason
        )
    }
}

extension SessionRecord: EmbraceStorageRecord {
    public static var entityName = "Session"

    static public var entityDescription: NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = entityName
        entity.managedObjectClassName = NSStringFromClass(SessionRecord.self)

        let idAttribute = NSAttributeDescription()
        idAttribute.name = "idRaw"
        idAttribute.attributeType = .stringAttributeType

        let processIdAttribute = NSAttributeDescription()
        processIdAttribute.name = "processIdRaw"
        processIdAttribute.attributeType = .stringAttributeType

        let stateAttribute = NSAttributeDescription()
        stateAttribute.name = "state"
        stateAttribute.attributeType = .stringAttributeType

        let traceIdAttribute = NSAttributeDescription()
        traceIdAttribute.name = "traceId"
        traceIdAttribute.attributeType = .stringAttributeType

        let spanIdAttribute = NSAttributeDescription()
        spanIdAttribute.name = "spanId"
        spanIdAttribute.attributeType = .stringAttributeType

        let startTimeAttribute = NSAttributeDescription()
        startTimeAttribute.name = "startTime"
        startTimeAttribute.attributeType = .dateAttributeType
        startTimeAttribute.defaultValue = Date()

        let endTimeAttribute = NSAttributeDescription()
        endTimeAttribute.name = "endTime"
        endTimeAttribute.attributeType = .dateAttributeType
        endTimeAttribute.isOptional = true

        let lastHeartbeatTimeAttribute = NSAttributeDescription()
        lastHeartbeatTimeAttribute.name = "lastHeartbeatTime"
        lastHeartbeatTimeAttribute.attributeType = .dateAttributeType

        let crashReportIdAttribute = NSAttributeDescription()
        crashReportIdAttribute.name = "crashReportId"
        crashReportIdAttribute.attributeType = .stringAttributeType
        crashReportIdAttribute.isOptional = true

        let coldStartAttribute = NSAttributeDescription()
        coldStartAttribute.name = "coldStart"
        coldStartAttribute.attributeType = .booleanAttributeType

        let cleanExitAttribute = NSAttributeDescription()
        cleanExitAttribute.name = "cleanExit"
        cleanExitAttribute.attributeType = .booleanAttributeType

        let appTerminatedAttribute = NSAttributeDescription()
        appTerminatedAttribute.name = "appTerminated"
        appTerminatedAttribute.attributeType = .booleanAttributeType

        let sessionNumberAttribute = NSAttributeDescription()
        sessionNumberAttribute.name = "sessionNumber"
        sessionNumberAttribute.attributeType = .integer64AttributeType
        sessionNumberAttribute.defaultValue = 0

        // user-session columns (v7)
        let userSessionIdAttribute = NSAttributeDescription()
        userSessionIdAttribute.name = "userSessionIdRaw"
        userSessionIdAttribute.attributeType = .stringAttributeType
        userSessionIdAttribute.isOptional = true

        let userSessionStartTimeAttribute = NSAttributeDescription()
        userSessionStartTimeAttribute.name = "userSessionStartTime"
        userSessionStartTimeAttribute.attributeType = .dateAttributeType
        userSessionStartTimeAttribute.isOptional = true

        let userSessionMaxDurationAttribute = NSAttributeDescription()
        userSessionMaxDurationAttribute.name = "userSessionMaxDuration"
        userSessionMaxDurationAttribute.attributeType = .doubleAttributeType
        userSessionMaxDurationAttribute.isOptional = true

        let userSessionInactivityTimeoutAttribute = NSAttributeDescription()
        userSessionInactivityTimeoutAttribute.name = "userSessionInactivityTimeout"
        userSessionInactivityTimeoutAttribute.attributeType = .doubleAttributeType
        userSessionInactivityTimeoutAttribute.isOptional = true

        let userSessionLastForegroundEndAttribute = NSAttributeDescription()
        userSessionLastForegroundEndAttribute.name = "userSessionLastForegroundEnd"
        userSessionLastForegroundEndAttribute.attributeType = .dateAttributeType
        userSessionLastForegroundEndAttribute.isOptional = true

        let userSessionPartIndexAttribute = NSAttributeDescription()
        userSessionPartIndexAttribute.name = "userSessionPartIndex"
        userSessionPartIndexAttribute.attributeType = .integer64AttributeType
        userSessionPartIndexAttribute.defaultValue = 0

        let userSessionEndReasonAttribute = NSAttributeDescription()
        userSessionEndReasonAttribute.name = "userSessionEndReason"
        userSessionEndReasonAttribute.attributeType = .stringAttributeType
        userSessionEndReasonAttribute.isOptional = true

        entity.properties = [
            idAttribute,
            processIdAttribute,
            stateAttribute,
            traceIdAttribute,
            spanIdAttribute,
            startTimeAttribute,
            endTimeAttribute,
            lastHeartbeatTimeAttribute,
            crashReportIdAttribute,
            coldStartAttribute,
            cleanExitAttribute,
            appTerminatedAttribute,
            sessionNumberAttribute,
            userSessionIdAttribute,
            userSessionStartTimeAttribute,
            userSessionMaxDurationAttribute,
            userSessionInactivityTimeoutAttribute,
            userSessionLastForegroundEndAttribute,
            userSessionPartIndexAttribute,
            userSessionEndReasonAttribute
        ]

        return entity
    }
}

struct ImmutableSessionRecord: EmbraceSession {
    let id: EmbraceIdentifier
    let processId: EmbraceIdentifier
    let state: SessionState
    let traceId: String
    let spanId: String
    let startTime: Date
    let endTime: Date?
    let lastHeartbeatTime: Date
    let crashReportId: String?
    let coldStart: Bool
    let cleanExit: Bool
    let appTerminated: Bool
    let sessionNumber: EMBInt
    let userSessionId: EmbraceIdentifier?
    let userSessionStartTime: Date?
    let userSessionMaxDuration: TimeInterval?
    let userSessionInactivityTimeout: TimeInterval?
    let userSessionLastForegroundEnd: Date?
    let userSessionPartIndex: EMBInt
    let userSessionEndReason: String?
}
