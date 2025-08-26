//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceConfiguration
import EmbraceStorageInternal
import Foundation
import EmbraceSemantics
@testable import EmbraceCore

public class DummyLogControllable: LogControllable {

    public init() {}

    public func uploadAllPersistedLogs() {}

    public func createLog(
        _ message: String,
        severity: EmbraceLogSeverity,
        type: EmbraceType,
        timestamp: Date,
        attachment: EmbraceLogAttachment?,
        attributes: [String: String],
        stackTraceBehavior: EmbraceStackTraceBehavior,
        send: Bool,
        completion: ((EmbraceLog?) -> Void)?
    ) {}

    public func batchFinished(withLogs logs: [EmbraceLog]) {}

    public var limits = LogsLimits()

    public var currentSessionId: EmbraceIdentifier?
}
