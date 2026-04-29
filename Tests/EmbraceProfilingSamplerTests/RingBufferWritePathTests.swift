//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS)

    import Darwin
    import EmbraceProfilingSampler
    import XCTest

    /// Tests for the ring buffer write path (reserve/commit) and read helper.
    final class RingBufferWritePathTests: XCTestCase {

        // MARK: - Basic write/read

        func test_writeRead_singleRecord() {
            let buf = emb_ring_buffer_create(1024 * 1024)
            guard let buf = buf else {
                XCTFail("emb_ring_buffer_create should succeed")
                return
            }
            defer { emb_ring_buffer_destroy(buf) }

            // Write a record.
            let testFrames: [UInt] = [0x1000, 0x2000, 0x3000]
            let timestamp: UInt64 = 123_456_789
            let success = emb_ring_buffer_write(buf, timestamp, testFrames, testFrames.count)
            XCTAssertTrue(success, "write should succeed")

            // Read back all records.
            let records = testReadRange(buf, 0, UINT64_MAX)

            XCTAssertEqual(records.count, 1, "should have 1 record")
            guard records.count == 1 else { return }

            let record = records[0]
            XCTAssertEqual(record.timestamp_ns, timestamp)
            XCTAssertEqual(record.frame_count, testFrames.count)

            // Verify frame data.
            for i in 0..<testFrames.count {
                XCTAssertEqual(record.frames[i], testFrames[i])
            }
        }

        func test_writeRead_multipleRecords() {
            let buf = emb_ring_buffer_create(1024 * 1024)
            guard let buf = buf else {
                XCTFail("emb_ring_buffer_create should succeed")
                return
            }
            defer { emb_ring_buffer_destroy(buf) }

            let recordCount = 10
            var expectedTimestamps: [UInt64] = []

            // Write multiple records with varying frame counts.
            for i in 0..<recordCount {
                let frameCount = (i % 5) + 1  // 1 to 5 frames
                var frames: [UInt] = []

                for j in 0..<frameCount {
                    frames.append(UInt(0x1000 * (i + 1) + j))
                }

                let timestamp = UInt64(100_000 * (i + 1))
                expectedTimestamps.append(timestamp)
                let success = emb_ring_buffer_write(buf, timestamp, frames, frameCount)
                XCTAssertTrue(success, "write \(i) should succeed")
            }

            // Read back all records.
            let records = testReadRange(buf, 0, UINT64_MAX)

            XCTAssertEqual(records.count, recordCount)

            for i in 0..<records.count {
                let record = records[i]
                XCTAssertEqual(record.timestamp_ns, expectedTimestamps[i])

                let expectedFrameCount = (i % 5) + 1
                XCTAssertEqual(record.frame_count, expectedFrameCount)

                // Verify frame data.
                for j in 0..<expectedFrameCount {
                    let expected = UInt(0x1000 * (i + 1) + j)
                    XCTAssertEqual(record.frames[j], expected)
                }
            }
        }

        // MARK: - Zero-frame records

        func test_writeRead_zeroFrames() {
            let buf = emb_ring_buffer_create(1024 * 1024)
            guard let buf = buf else {
                XCTFail("emb_ring_buffer_create should succeed")
                return
            }
            defer { emb_ring_buffer_destroy(buf) }

            // Write a zero-frame record.
            let timestamp: UInt64 = 999_999
            let frames: [UInt] = []
            let success = emb_ring_buffer_write(buf, timestamp, frames, 0)
            XCTAssertTrue(success, "write should succeed")

            // Read back.
            let records = testReadRange(buf, 0, UINT64_MAX)

            XCTAssertEqual(records.count, 1)
            guard records.count == 1 else { return }

            let record = records[0]
            XCTAssertEqual(record.timestamp_ns, timestamp)
            XCTAssertEqual(record.frame_count, 0)
        }

        // MARK: - Variable-length records

        func test_writeRead_variableLengths() {
            let buf = emb_ring_buffer_create(1024 * 1024)
            guard let buf = buf else {
                XCTFail("emb_ring_buffer_create should succeed")
                return
            }
            defer { emb_ring_buffer_destroy(buf) }

            let frameCounts = [0, 1, 10, 50, 100, 200, 512]
            var expectedData: [(timestamp: UInt64, frameCount: Int)] = []

            for (idx, frameCount) in frameCounts.enumerated() {
                // Create unique patterns.
                var frames: [UInt] = []
                for i in 0..<frameCount {
                    frames.append(UInt(0x10000 * (idx + 1) + i))
                }

                let timestamp = UInt64(1_000_000 * (idx + 1))
                expectedData.append((timestamp, frameCount))
                let success = emb_ring_buffer_write(buf, timestamp, frames, frameCount)
                XCTAssertTrue(success, "write \(idx) should succeed")
            }

            // Read back.
            let records = testReadRange(buf, 0, UINT64_MAX)

            XCTAssertEqual(records.count, frameCounts.count)

            for i in 0..<records.count {
                let record = records[i]
                XCTAssertEqual(record.timestamp_ns, expectedData[i].timestamp)
                XCTAssertEqual(record.frame_count, expectedData[i].frameCount)

                // Verify frames.
                for j in 0..<expectedData[i].frameCount {
                    let expected = UInt(0x10000 * (i + 1) + j)
                    XCTAssertEqual(record.frames[j], expected)
                }
            }
        }

        // MARK: - Wrap-around

        func test_writeRead_wrapAround() {
            // Use a small buffer to force wrap-around quickly.
            let pageSize = Int(getpagesize())
            let buf = emb_ring_buffer_create(pageSize)
            guard let buf = buf else {
                XCTFail("emb_ring_buffer_create should succeed")
                return
            }
            defer { emb_ring_buffer_destroy(buf) }

            let capacity = buf.pointee.capacity
            let recordSize = 16 + 10 * 8  // Header + 10 frames
            let recordsToFill = Int(capacity) / recordSize + 10  // Overfill to wrap

            var lastTimestamps: [UInt64] = []

            // Write enough records to wrap around multiple times.
            for i in 0..<recordsToFill {
                var frames: [UInt] = []
                for j in 0..<10 {
                    frames.append(UInt(0x1000 * i + j))
                }

                let timestamp = UInt64(i + 1)
                lastTimestamps.append(timestamp)
                let success = emb_ring_buffer_write(buf, timestamp, frames, 10)
                XCTAssertTrue(success, "write \(i) should succeed")
            }

            // Read back. Should get only the records that fit in the buffer
            // (oldest records evicted).
            let records = testReadRange(buf, 0, UINT64_MAX)

            XCTAssertGreaterThan(records.count, 0, "should have some records")
            XCTAssertLessThan(records.count, recordsToFill, "should have evicted old records")

            // The timestamps should be from the most recent records.
            let expectedStartIndex = recordsToFill - records.count
            for i in 0..<records.count {
                let record = records[i]
                let expected = lastTimestamps[expectedStartIndex + i]
                XCTAssertEqual(
                    record.timestamp_ns, expected,
                    "record \(i) timestamp mismatch")
            }
        }

        // MARK: - Eviction correctness

        func test_eviction_dropsOldRecords() {
            let pageSize = Int(getpagesize())
            let buf = emb_ring_buffer_create(pageSize)
            guard let buf = buf else {
                XCTFail("emb_ring_buffer_create should succeed")
                return
            }
            defer { emb_ring_buffer_destroy(buf) }

            let capacity = buf.pointee.capacity
            let recordSize = 16 + 10 * 8
            let recordsToFill = Int(capacity) / recordSize
            let overwriteCount = 5

            // Fill buffer then write more to evict.
            for i in 0..<(recordsToFill + overwriteCount) {
                var frames: [UInt] = []
                for j in 0..<10 {
                    frames.append(UInt(i * 100 + j))
                }

                let success = emb_ring_buffer_write(buf, UInt64(i), frames, 10)
                XCTAssertTrue(success, "write \(i) should succeed")
            }

            // Read back.
            let records = testReadRange(buf, 0, UINT64_MAX)

            // Should not contain the first `overwriteCount` records.
            XCTAssertGreaterThan(records.count, 0)

            if records.count > 0 {
                let firstTimestamp = records[0].timestamp_ns
                XCTAssertGreaterThanOrEqual(
                    firstTimestamp, UInt64(overwriteCount),
                    "oldest records should be evicted")
            }
        }

        // MARK: - Edge cases

        func test_write_withNilBuffer_returnsFalse() {
            let frames: [UInt] = [0x1000, 0x2000]
            let success = emb_ring_buffer_write(nil, 123, frames, 2)
            XCTAssertFalse(success)
        }

        func test_write_withNilFrames_returnsFalse() {
            let buf = emb_ring_buffer_create(1024 * 1024)
            guard let buf = buf else {
                XCTFail("emb_ring_buffer_create should succeed")
                return
            }
            defer { emb_ring_buffer_destroy(buf) }

            let success = emb_ring_buffer_write(buf, 123, nil, 10)
            XCTAssertFalse(success)
        }

        func test_readRange_withNilBuffer_returnsEmpty() {
            var output = [UInt8](repeating: 0, count: 16)
            let result = emb_ring_buffer_read_range(nil, 0, UINT64_MAX, &output, output.count)
            XCTAssertEqual(result.record_count, 0)
        }

        func test_readRange_filtersOnTimestamp() {
            let buf = emb_ring_buffer_create(1024 * 1024)
            guard let buf = buf else {
                XCTFail("emb_ring_buffer_create should succeed")
                return
            }
            defer { emb_ring_buffer_destroy(buf) }

            // Write 10 records with timestamps 1000, 2000, ..., 10000.
            for i in 0..<10 {
                let frames: [UInt] = [UInt(i)]
                let timestamp = UInt64((i + 1) * 1000)
                let success = emb_ring_buffer_write(buf, timestamp, frames, 1)
                XCTAssertTrue(success)
            }

            // Read only records from 3000 to 7000 (inclusive).
            let records = testReadRange(buf, 3000, 7000)

            // Should get 5 records: timestamps 3000, 4000, 5000, 6000, 7000.
            XCTAssertEqual(records.count, 5)

            for i in 0..<records.count {
                let record = records[i]
                let expectedTimestamp = UInt64((i + 3) * 1000)
                XCTAssertEqual(record.timestamp_ns, expectedTimestamp)
                XCTAssertEqual(record.frame_count, 1)
            }
        }

        func test_readAll_emptyBuffer_returnsEmpty() {
            let buf = emb_ring_buffer_create(1024 * 1024)
            guard let buf = buf else {
                XCTFail("emb_ring_buffer_create should succeed")
                return
            }
            defer { emb_ring_buffer_destroy(buf) }

            let records = testReadRange(buf, 0, UINT64_MAX)
            XCTAssertEqual(records.count, 0)
        }
    }

#endif
