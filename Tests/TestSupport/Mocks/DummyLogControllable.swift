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
        attachment: Data?,
        attachmentId: String?,
        attachmentUrl: URL?,
        attributes: [String: String],
        stackTraceBehavior: StackTraceBehavior,
        queue: DispatchQueue
    ) {}

    public func batchFinished(withLogs logs: [EmbraceLog]) {}

    public var limits = LogsLimits()

    public var currentSessionId: EmbraceIdentifier?
}
