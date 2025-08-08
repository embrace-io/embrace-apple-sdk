//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

public protocol EmbraceSession {
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
}
