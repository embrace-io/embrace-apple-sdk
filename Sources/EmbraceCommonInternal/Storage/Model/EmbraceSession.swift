//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public protocol EmbraceSession {
    var idRaw: String { get set }
    var processIdRaw: String { get set }
    var state: String { get set }
    var traceId: String { get set }
    var spanId: String { get set }
    var startTime: Date { get set }
    var endTime: Date? { get set }
    var lastHeartbeatTime: Date { get set }
    var crashReportId: String? { get set }
    var coldStart: Bool { get set }
    var cleanExit: Bool { get set }
    var appTerminated: Bool { get set }
}

public extension EmbraceSession {
    var id: SessionIdentifier? {
        return SessionIdentifier(string: idRaw)
    }

    var processId: ProcessIdentifier? {
        return ProcessIdentifier(hex: processIdRaw)
    }
}
