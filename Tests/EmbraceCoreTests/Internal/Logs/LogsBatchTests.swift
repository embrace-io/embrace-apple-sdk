//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceSemantics
import EmbraceStorageInternal
import Foundation
import TestSupport
import XCTest

@testable import EmbraceCore

class LogsBatchTests: XCTestCase {
    private var sut: LogsBatch!
    private var limits: LogBatchLimits!
    private var batchingResult: LogsBatch.BatchingResult!

    func test_onInit_batchStateShouldBeAlwaysOpen() {
        givenNonZeroLogLimits()
        whenInitializing()
        thenBatch(is: .open)
    }

    func testHavingRecentLogs_batchStateShouldBeOpen() {
        givenLimits(maxBatchAge: Double.infinity)
        givenLogBatch(logs: [recentLog()])
        thenBatch(is: .open)
    }

    func testHavingOldLog_batchStateShouldBeClosed() {
        givenLimits(maxBatchAge: 10)
        givenLogBatch(logs: [randomLog(date: Date().addingTimeInterval(-60))])
        thenBatch(is: .closed)
    }

    func testHavingFullBatch_batchStateShouldBeClosed() {
        givenLimits(maxLogsPerBatch: 1)
        givenLogBatch(logs: [randomLog()])
        thenBatch(is: .closed)
    }

    func testHavingClosedBatch_whenAddingLog_shouldReturnFailureWithoutAddingIt() {
        givenLimits(maxLogsPerBatch: 1)
        givenLogBatch(logs: [randomLog()])
        whenAddingLog(randomLog())
        thenResult(is: .failure)
        thenBatchLogCount(is: 1)
    }

    func testHavingOpenBatch_whenAddingLog_shouldAddLogAndReturnOpenState() {
        givenLimits(maxLogsPerBatch: 10)
        givenLogBatch()
        whenAddingLog(randomLog())
        thenResult(is: .success(batchState: .open))
        thenBatchLogCount(is: 1)
    }

    func testHavingOpenBatchAboutToBeClosed_whenAddingLog_shouldAddLogAndReturnOpenState() {
        givenLimits(maxLogsPerBatch: 1)
        givenLogBatch()
        whenAddingLog(randomLog())
        thenResult(is: .success(batchState: .closed))
        thenBatchLogCount(is: 1)
    }
}

extension LogsBatchTests {
    fileprivate func givenNonZeroLogLimits() {
        givenLimits(
            maxBatchAge: .random(in: 1..<100),
            maxLogsPerBatch: .random(in: 1..<100)
        )
    }

    fileprivate func givenLimits(
        maxBatchAge: Double = .random(in: 1..<100), maxLogsPerBatch: Int = .random(in: 1..<100)
    ) {
        limits = .init(maxBatchAge: maxBatchAge, maxLogsPerBatch: maxLogsPerBatch)
    }

    fileprivate func givenLogBatch(logs: [EmbraceLog] = []) {
        sut = .init(limits: limits, logs: logs)
    }

    fileprivate func whenInitializing() {
        givenLogBatch(logs: [])
    }

    fileprivate func whenAddingLog(_ log: EmbraceLog) {
        batchingResult = sut.add(log: log)
    }

    fileprivate func thenResult(is result: LogsBatch.BatchingResult) {
        XCTAssertEqual(batchingResult, result)
    }

    fileprivate func thenBatchLogCount(is batchLogCount: Int) {
        XCTAssertEqual(sut.logs.count, batchLogCount)
    }

    fileprivate func thenBatch(is state: LogsBatch.BatchState) {
        XCTAssertEqual(sut.batchState, state)
    }

    fileprivate func recentLog() -> EmbraceLog {
        randomLog(date: Date())
    }

    fileprivate func randomLog(date: Date = Date()) -> EmbraceLog {
        return MockLog(timestamp: date)
    }
}

extension LogsBatch.BatchingResult: Equatable {
    public static func == (lhs: LogsBatch.BatchingResult, rhs: LogsBatch.BatchingResult) -> Bool {
        switch (lhs, rhs) {
        case (.success(let lhsBatchState), .success(let rhsBatchState)):
            return lhsBatchState == rhsBatchState
        case (.failure, .failure):
            return true
        default:
            return false
        }
    }
}
