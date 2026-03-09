//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceProfiling
import XCTest

final class ProfilingEngineTests: XCTestCase {

    func test_init_isNotRunning() {
        let engine = ProfilingEngine()
        XCTAssertFalse(engine.isRunning)
    }

    func test_startAndStop() throws {
        let engine = ProfilingEngine()

        try engine.start()
        XCTAssertTrue(engine.isRunning)

        engine.stop()
        XCTAssertFalse(engine.isRunning)
    }

    func test_startWhileRunning_isIgnored() throws {
        let engine = ProfilingEngine()
        try engine.start()
        try engine.start()  // should not throw or reset state
        XCTAssertTrue(engine.isRunning)
        engine.stop()
    }

    func test_retrieveSamples_returnsEmptyBeforeStart() {
        let engine = ProfilingEngine()
        let samples = engine.retrieveSamples(from: 0, through: UInt64.max)
        XCTAssertTrue(samples.isEmpty)
    }

    func test_retrieveSamples_returnsDataAfterRunning() throws {
        let engine = ProfilingEngine()
        try engine.start()

        // Let samples accumulate (default interval is 100ms)
        Thread.sleep(forTimeInterval: 0.35)

        engine.stop()

        let samples = engine.retrieveSamples(from: 0, through: UInt64.max)
        XCTAssertGreaterThanOrEqual(samples.count, 2, "Expected at least 2 samples after 350ms at 100ms interval")

        for sample in samples {
            XCTAssertGreaterThan(sample.timestamp, 0)
            XCTAssertFalse(sample.frames.isEmpty)
        }
    }

    func test_retrieveSamples_availableAfterStop() throws {
        let engine = ProfilingEngine()
        try engine.start()
        Thread.sleep(forTimeInterval: 0.25)
        engine.stop()

        // Pull-based: samples remain available after the engine has stopped
        let samples = engine.retrieveSamples(from: 0, through: UInt64.max)
        XCTAssertFalse(samples.isEmpty, "Samples should persist after stop")
    }

    func test_retrieveSamples_timeRangeFiltering() throws {
        let engine = ProfilingEngine()
        try engine.start()
        Thread.sleep(forTimeInterval: 0.55)
        engine.stop()

        let allSamples = engine.retrieveSamples(from: 0, through: UInt64.max)
        guard allSamples.count >= 3 else {
            XCTFail("Expected at least 3 samples for time-range test, got \(allSamples.count)")
            return
        }

        // Ask for only the second half — should return fewer samples
        let midTimestamp = allSamples[allSamples.count / 2].timestamp
        let laterSamples = engine.retrieveSamples(from: midTimestamp, through: UInt64.max)
        XCTAssertLessThan(
            laterSamples.count, allSamples.count,
            "Narrower time range should yield fewer samples")
    }

    func test_samplesHaveOrderedTimestamps() throws {
        let engine = ProfilingEngine()
        try engine.start()
        Thread.sleep(forTimeInterval: 0.35)
        engine.stop()

        let samples = engine.retrieveSamples(from: 0, through: UInt64.max)
        for i in 1..<samples.count {
            XCTAssertGreaterThan(
                samples[i].timestamp, samples[i - 1].timestamp,
                "Samples should have strictly increasing timestamps")
        }
    }
}
