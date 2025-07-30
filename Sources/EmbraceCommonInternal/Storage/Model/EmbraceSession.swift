//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public protocol EmbraceSession {
    var idRaw: String { get }
    var processIdRaw: String { get }
    var state: String { get }
    var traceId: String { get }
    var spanId: String { get }
    var startTime: Date { get }
    var endTime: Date? { get }
    var lastHeartbeatTime: Date { get }
    var crashReportId: String? { get }
    var coldStart: Bool { get }
    var cleanExit: Bool { get }
    var appTerminated: Bool { get }
}

extension EmbraceSession {
    public var id: SessionIdentifier? {
        return SessionIdentifier(string: idRaw)
    }

    public var processId: ProcessIdentifier? {
        return ProcessIdentifier(string: processIdRaw)
    }
}
