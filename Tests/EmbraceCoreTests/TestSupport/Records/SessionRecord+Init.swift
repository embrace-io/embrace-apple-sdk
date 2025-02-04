//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal
import EmbraceStorageInternal

extension SessionRecord {
    convenience init(
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
        self.init()

        self.idRaw = id.toString
        self.processIdRaw = processId.hex
        self.state = state.rawValue
        self.traceId = traceId
        self.spanId = spanId
        self.startTime = startTime
        self.endTime = endTime
        self.lastHeartbeatTime = ((lastHeartbeatTime ?? endTime) ?? startTime)
        self.crashReportId = crashReportId
        self.coldStart = coldStart
        self.cleanExit = cleanExit
        self.appTerminated = appTerminated
    }
}
