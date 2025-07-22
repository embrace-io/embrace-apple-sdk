//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import Foundation

public class MockSession: EmbraceSession {
    public var idRaw: String
    public var processIdRaw: String
    public var state: String
    public var traceId: String
    public var spanId: String
    public var startTime: Date
    public var endTime: Date?
    public var lastHeartbeatTime: Date
    public var crashReportId: String?
    public var coldStart: Bool
    public var cleanExit: Bool
    public var appTerminated: Bool

    public init(
        id: SessionIdentifier,
        processId: ProcessIdentifier,
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
        self.idRaw = id.toString
        self.processIdRaw = processId.hex
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
    public static func with(id: SessionIdentifier, state: SessionState) -> MockSession {
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
