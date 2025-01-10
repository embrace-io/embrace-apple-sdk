//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
@testable import EmbraceCore
import EmbraceCommonInternal
import EmbraceStorageInternal

public class DummyLogControllable: LogControllable {

    public init() {}
    
    public func uploadAllPersistedLogs() {}

    public func createLog(
        _ message: String,
        severity: LogSeverity,
        type: LogType,
        timestamp: Date,
        attachment: Data?,
        attachmentId: String?,
        attachmentUrl: URL?,
        attachmentSize: Int?,
        attributes: [String : String],
        stackTraceBehavior: StackTraceBehavior
    ) { }

    public func batchFinished(withLogs logs: [LogRecord]) {}
}
