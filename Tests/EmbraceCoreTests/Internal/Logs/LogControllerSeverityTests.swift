//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceSemantics
import EmbraceStorageInternal
import TestSupport
import XCTest

@testable import EmbraceCore

class LogControllerSeverityTests: XCTestCase {

    private func makeController(batcher: LogBatcher) -> LogController {
        LogController(
            storage: nil,
            upload: nil,
            sessionController: MockSessionController(),
            batcher: batcher,
            queue: DispatchQueue(label: "com.embrace.logcontroller.severity.test")
        )
    }

    func test_createLog_criticalSeverity_isRejected() {
        // given a log controller
        let batcher = SpyLogBatcher()
        let controller = makeController(batcher: batcher)

        // when creating a log with the internal-only `.critical` severity
        controller.createLog("internal only", severity: .critical)

        // then no log is handed to the batcher (the public API rejects `.critical`)
        XCTAssertTrue(batcher.addedLogs.isEmpty)
    }

    func test_onSessionPartWillEnd_forceEndsCurrentBatch() {
        // given a log controller observing session-part-will-end
        let batcher = SpyLogBatcher()
        let controller = makeController(batcher: batcher)
        _ = controller  // keep alive for the duration of the notification dispatch

        // when a session part is about to end
        NotificationCenter.default.post(name: .embraceSessionPartWillEnd, object: nil)

        // then the current batch is force-ended synchronously so the session's logs ship with it
        XCTAssertEqual(batcher.forceEndCallCount, 1)
        XCTAssertEqual(batcher.lastForceEndWaitUntilFinished, true)
    }
}

private final class SpyLogBatcher: LogBatcher {
    private(set) var addedLogs: [EmbraceLog] = []
    private(set) var forceEndCallCount = 0
    private(set) var lastForceEndWaitUntilFinished: Bool?

    let logBatchLimits = LogBatchLimits()
    weak var delegate: LogBatcherDelegate?
    var batch: LogsBatch?

    func addLog(_ log: EmbraceLog) {
        addedLogs.append(log)
    }

    func renewBatch(withLogs logRecords: [EmbraceLog]) {}

    func forceEndCurrentBatch(waitUntilFinished: Bool) {
        forceEndCallCount += 1
        lastForceEndWaitUntilFinished = waitUntilFinished
    }
}
