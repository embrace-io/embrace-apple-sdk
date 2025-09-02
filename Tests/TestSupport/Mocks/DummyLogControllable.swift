//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceConfiguration
import EmbraceStorageInternal
import Foundation

@testable import EmbraceCore

public class DummyLogControllable: LogControllable {

    public init() {}

    public func uploadAllPersistedLogs(_ completion: (() -> Void)?) {
        completion?()
    }

    public func createLog(
        _ message: String,
        severity: LogSeverity,
        type: LogType,
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
}
