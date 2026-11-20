//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS) && !os(macOS)

    import XCTest

    @testable import EmbraceCore

    final class FrameTraceRecorderTests: XCTestCase {

        private var recorder: FrameTraceRecorder!
        private var now: TimeInterval = 1_000

        override func setUp() {
            super.setUp()
            recorder = FrameTraceRecorder()
            now = 1_000
        }

        override func tearDown() {
            recorder = nil
            super.tearDown()
        }

        // MARK: - Helpers

        /// Records a tick `seconds` after the previous one.
        private func record(after seconds: TimeInterval) {
            let previous = now
            now += seconds
            recorder.record(
                FrameTimingSource.Tick(timestamp: now, previousTimestamp: previous, delay: 0, frameInterval: 1.0 / 60.0, previousFrameInterval: 1.0 / 60.0)
            )
        }

        /// Records a tick a whole number of milliseconds after the previous one. A nanosecond over, so
        /// floating-point error can't truncate it to the millisecond below.
        private func record(milliseconds: Int) {
            record(after: TimeInterval(milliseconds) / 1000 + 1e-9)
        }

        private func recordCommitted(milliseconds: [Int]) {
            milliseconds.forEach(record(milliseconds:))
            recorder.commit()
        }

        // MARK: - Encoding

        func testEmptyTraceIsNil() {
            XCTAssertNil(recorder.trace)

            recorder.commit()
            XCTAssertNil(recorder.trace)
        }

        func testSmallIntervalsTakeOneByteEach() {
            recordCommitted(milliseconds: [1, 16, 127])

            XCTAssertEqual(recorder.trace.map { [UInt8]($0) }, [1, 16, 127])
        }

        func testLargeIntervalsUseContinuationBytes() {
            recordCommitted(milliseconds: [128, 300, 16_384])

            XCTAssertEqual(recorder.trace.map { [UInt8]($0) }, [0x80, 0x01, 0xAC, 0x02, 0x80, 0x80, 0x01])
            XCTAssertEqual(recorder.trace?.decodedVarints, [128, 300, 16_384])
        }

        func testIntervalsAreTruncatedToWholeMilliseconds() {
            record(after: 1.0 / 120.0)
            record(after: 1.0 / 60.0)
            record(after: 0.0169)
            recorder.commit()

            XCTAssertEqual(recorder.trace?.decodedVarints, [8, 16, 16])
        }

        func testNegativeIntervalRecordsZero() {
            record(after: -0.01)
            recorder.commit()

            XCTAssertEqual(recorder.trace?.decodedVarints, [0])
        }

        // MARK: - Commit

        func testUncommittedTicksAreNotInTrace() {
            recordCommitted(milliseconds: [16])
            record(milliseconds: 16)
            record(milliseconds: 16)

            XCTAssertEqual(recorder.trace?.decodedVarints, [16])
        }

        func testCommitKeepsEarlierUncommittedTicks() {
            recordCommitted(milliseconds: [16])
            record(milliseconds: 33)
            recordCommitted(milliseconds: [8])

            XCTAssertEqual(recorder.trace?.decodedVarints, [16, 33, 8])
        }

        func testResetStartsNewTrace() {
            recordCommitted(milliseconds: [16, 200])

            recorder.reset()
            XCTAssertNil(recorder.trace)

            recordCommitted(milliseconds: [8])
            XCTAssertEqual(recorder.trace?.decodedVarints, [8])
        }

        // MARK: - Capacity

        func testDefaultCapacityHolds1024OneByteTicks() {
            recordCommitted(milliseconds: Array(repeating: 16, count: 1_100))

            XCTAssertEqual(recorder.trace?.count, 1024)
        }

        func testOverflowStopsAtFirstVarintThatDoesNotFit() {
            recorder = FrameTraceRecorder(capacity: 3)

            // Two bytes fit, then a two-byte varint doesn't; the later one-byte varint must not fill the gap.
            recordCommitted(milliseconds: [16, 16, 300, 16])

            XCTAssertEqual(recorder.trace?.decodedVarints, [16, 16])
        }

        func testResetClearsOverflow() {
            recorder = FrameTraceRecorder(capacity: 1)
            recordCommitted(milliseconds: [16, 16])

            recorder.reset()
            recordCommitted(milliseconds: [8])

            XCTAssertEqual(recorder.trace?.decodedVarints, [8])
        }
    }

    extension Data {
        /// Decodes unsigned LEB128 varints. A truncated final varint is dropped.
        var decodedVarints: [UInt64] {
            var values: [UInt64] = []
            var value: UInt64 = 0
            var shift: UInt64 = 0
            for byte in self {
                value |= UInt64(byte & 0x7F) << shift
                if byte & 0x80 == 0 {
                    values.append(value)
                    value = 0
                    shift = 0
                } else {
                    shift += 7
                }
            }
            return values
        }
    }

#endif  // !os(watchOS) && !os(macOS)
