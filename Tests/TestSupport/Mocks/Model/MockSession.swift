//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceSemantics
import EmbraceCommonInternal
import Foundation

public class MockSession: EmbraceSession {
    public var id: EmbraceIdentifier
    public var processId: EmbraceIdentifier
    public var state: SessionState
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
        self.id = id
        self.processId = processId
        self.state = state
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
