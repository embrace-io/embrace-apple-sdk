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

    func test_onSessionPartWillEnd_forceEndsCurrentBatchWithEndingSession() {
        // given a log controller observing session-part-will-end
        let batcher = SpyLogBatcher()
        let controller = makeController(batcher: batcher)
        _ = controller  // keep alive for the duration of the notification dispatch
        let endingSession = MockSession.with(id: .random, state: .foreground)

        // when a session part is about to end
        NotificationCenter.default.post(name: .embraceSessionPartWillEnd, object: endingSession)

        // then the current batch is force-ended with the session carried by the notification
        XCTAssertEqual(batcher.forceEndCallCount, 1)
        XCTAssertEqual(batcher.lastForceEndSession?.id, endingSession.id)
    }
}

private final class SpyLogBatcher: LogBatcher {
    private(set) var addedLogs: [EmbraceLog] = []
    private(set) var forceEndCallCount = 0
    private(set) var lastForceEndSession: EmbraceSession?

    let logBatchLimits = LogBatchLimits()
    weak var delegate: LogBatcherDelegate?

    func currentBatch() -> LogsBatch? { nil }

    func addLog(_ log: EmbraceLog) {
        addedLogs.append(log)
    }

    func renewBatch(withLogs logRecords: [EmbraceLog]) {}

    func forceEndCurrentBatch(endingSession: EmbraceSession?) {
        forceEndCallCount += 1
        lastForceEndSession = endingSession
    }
}
