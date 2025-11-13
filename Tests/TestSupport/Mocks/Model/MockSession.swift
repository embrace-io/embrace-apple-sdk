//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import Foundation

final public class MockSession: EmbraceSession {
    public let idRaw: String
    public let processIdRaw: String
    public let state: String
    public let traceId: String
    public let spanId: String
    public let startTime: Date
    public let endTime: Date?
    public let lastHeartbeatTime: Date
    public let crashReportId: String?
    public let coldStart: Bool
    public let cleanExit: Bool
    public let appTerminated: Bool

    public init(
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
        appTerminated: Bool = false
    ) {
        self.idRaw = id.stringValue
        self.processIdRaw = processId.stringValue
        self.state = state.rawValue
        self.traceId = traceId
        self.spanId = spanId
        self.startTime = startTime
        self.endTime = endTime
        self.lastHeartbeatTime = lastHeartbeatTime ?? (endTime ?? startTime)
        self.crashReportId = crashReportId
        self.coldStart = coldStart
        self.cleanExit = cleanExit
        self.appTerminated = appTerminated
    }
}

extension MockSession {
    public static func with(id: EmbraceIdentifier, state: SessionState) -> MockSession {
        MockSession(
            id: id,
            processId: .random,
            state: state,
            traceId: "",
            spanId: "",
            startTime: Date()
        )
    }
}

extension MockSession {
    public func copyWithCrashReportId(_ crid: String) -> MockSession {
        MockSession(
            id: EmbraceIdentifier(stringValue: idRaw),
            processId: processId!,
            state: SessionState(rawValue: state)!,
            traceId: traceId,
            spanId: spanId,
            startTime: startTime,
            endTime: endTime,
            lastHeartbeatTime: lastHeartbeatTime,
            crashReportId: crid,
            coldStart: coldStart,
            cleanExit: cleanExit,
            appTerminated: appTerminated
        )
    }
}
