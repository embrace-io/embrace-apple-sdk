//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS)

    import Darwin
    import EmbraceProfilingSampler
    import XCTest

    /// Edge-case tests for emb_ring_buffer.
    /// All scenarios assume one periodic writer and zero or more concurrent readers.
    final class RingBufferEdgeCaseTests: XCTestCase {

        // Record layout constants (64-bit):
        //   _Atomic uint32_t seq       = 4 bytes
        //   uint32_t frame_count       = 4 bytes
        //   uint64_t timestamp_ns      = 8 bytes
        //   + 8 bytes per frame
        static let headerSize = 16
        static let frameSize = 8

        static func recordSize(_ frameCount: Int) -> Int {
            headerSize + frameSize * frameCount
        }

        // MARK: - Lifecycle

        func test_create_zeroCapacity_returnsNil() {
            // round_size_up_to_page_boundary(0) == 0, implementation returns NULL.
            let buf = emb_ring_buffer_create(0)
            XCTAssertNil(buf)
        }

        func test_create_oneByte_roundsUpToOnePage() {
            let buf = emb_ring_buffer_create(1)
            guard let buf else { return XCTFail("create(1) should succeed") }
            defer { emb_ring_buffer_destroy(buf) }

            let page = Int(getpagesize())
            XCTAssertEqual(buf.pointee.capacity, page)
        }

        func test_create_exactlyOnePage_noRounding() {
            let page = Int(getpagesize())
            let buf = emb_ring_buffer_create(page)
            guard let buf else { return XCTFail() }
            defer { emb_ring_buffer_destroy(buf) }

            XCTAssertEqual(buf.pointee.capacity, page)
        }

        func test_create_pagePlusOne_roundsUpToTwoPages() {
            let page = Int(getpagesize())
            let buf = emb_ring_buffer_create(page + 1)
            guard let buf else { return XCTFail() }
            defer { emb_ring_buffer_destroy(buf) }

            XCTAssertEqual(buf.pointee.capacity, 2 * page)
        }

        func test_create_largeCapacity_succeeds() {
            let buf = emb_ring_buffer_create(16 * 1024 * 1024)
            guard let buf else { return XCTFail("16 MB buffer should succeed") }
            defer { emb_ring_buffer_destroy(buf) }

            XCTAssertGreaterThanOrEqual(buf.pointee.capacity, 16 * 1024 * 1024)
        }

        func test_create_freshBuffer_isEmpty() {
            let buf = emb_ring_buffer_create(1024 * 1024)
            guard let buf else { return XCTFail() }
            defer { emb_ring_buffer_destroy(buf) }

            var result = emb_ring_buffer_read_range(buf, 0, UINT64_MAX)
            defer { emb_ring_read_result_free(&result) }
            XCTAssertEqual(result.count, 0)
            XCTAssertNil(result.records)
        }

        func test_destroy_nil_doesNotCrash() {
            emb_ring_buffer_destroy(nil)
        }

        func test_create_destroy_repeatedCycles_noLeak() {
            for i in 1...8 {
                let size = i * 64 * 1024
                let buf = emb_ring_buffer_create(size)
                XCTAssertNotNil(buf, "cycle \(i): create should succeed")
                emb_ring_buffer_destroy(buf)
            }
        }

        // MARK: - next_seq progression

        func test_nextSeq_startsAtZero() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }
            XCTAssertEqual(buf.pointee.next_seq, 0)
        }

        func test_nextSeq_incrementsBy2PerSuccessfulWrite() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            let frames: [UInt] = [0xCAFE]
            for i in 1...10 {
                emb_ring_buffer_write(buf, UInt64(i) * 1_000, frames, frames.count)
                XCTAssertEqual(
                    buf.pointee.next_seq, UInt64(i * 2),
                    "next_seq after \(i) writes")
            }
        }

        func test_nextSeq_unchangedOnNilBufferWrite() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            emb_ring_buffer_write(nil, 1_000, [UInt(1)], 1)
            XCTAssertEqual(buf.pointee.next_seq, 0)
        }

        func test_nextSeq_unchangedOnNilFramesWrite() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            emb_ring_buffer_write(buf, 1_000, nil, 5)
            XCTAssertEqual(buf.pointee.next_seq, 0)
        }

        func test_nextSeq_incrementsForZeroFrameRecords() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            let empty: [UInt] = []
            emb_ring_buffer_write(buf, 1_000, empty, 0)
            XCTAssertEqual(buf.pointee.next_seq, 2)
        }

        // MARK: - Write returns false on bad inputs

        func test_write_nilBuffer_returnsFalse() {
            let frames: [UInt] = [1, 2, 3]
            XCTAssertFalse(emb_ring_buffer_write(nil, 1_000, frames, frames.count))
        }

        func test_write_nilFrames_returnsFalse() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }
            XCTAssertFalse(emb_ring_buffer_write(buf, 1_000, nil, 3))
        }

        func test_write_nilFrames_leavesBufferEmpty() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }
            emb_ring_buffer_write(buf, 1_000, nil, 3)

            var result = emb_ring_buffer_read_range(buf, 0, UINT64_MAX)
            defer { emb_ring_read_result_free(&result) }
            XCTAssertEqual(result.count, 0)
        }

        // MARK: - Frame data preservation

        func test_frameData_exactValuesPreserved() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            let frames: [UInt] = [0xDEAD_BEEF, 0xCAFE_BABE, 0x1234_5678, 0xFFFF_FFFF]
            emb_ring_buffer_write(buf, 42_000, frames, frames.count)

            var result = emb_ring_buffer_read_range(buf, 0, UINT64_MAX)
            defer { emb_ring_read_result_free(&result) }

            XCTAssertEqual(result.count, 1)
            XCTAssertEqual(result.records[0].frame_count, frames.count)
            for i in 0..<frames.count {
                XCTAssertEqual(result.records[0].frames[i], frames[i], "frame \(i)")
            }
        }

        func test_frameData_allZeros_preserved() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            let frames = [UInt](repeating: 0, count: 8)
            emb_ring_buffer_write(buf, 1_000, frames, frames.count)

            var result = emb_ring_buffer_read_range(buf, 0, UINT64_MAX)
            defer { emb_ring_read_result_free(&result) }

            XCTAssertEqual(result.count, 1)
            for i in 0..<frames.count {
                XCTAssertEqual(result.records[0].frames[i], 0, "frame \(i)")
            }
        }

        func test_frameData_allMaxValue_preserved() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            let frames = [UInt](repeating: UInt.max, count: 8)
            emb_ring_buffer_write(buf, 2_000, frames, frames.count)

            var result = emb_ring_buffer_read_range(buf, 0, UINT64_MAX)
            defer { emb_ring_read_result_free(&result) }

            XCTAssertEqual(result.count, 1)
            for i in 0..<frames.count {
                XCTAssertEqual(result.records[0].frames[i], UInt.max, "frame \(i)")
            }
        }

        func test_frameData_largeFrameCount_preserved() {
            let buf = emb_ring_buffer_create(4 * 1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            let count = 512
            let frames = (0..<count).map { UInt($0 + 1) }
            emb_ring_buffer_write(buf, 99_000, frames, count)

            var result = emb_ring_buffer_read_range(buf, 0, UINT64_MAX)
            defer { emb_ring_read_result_free(&result) }

            XCTAssertEqual(result.count, 1)
            XCTAssertEqual(result.records[0].frame_count, count)
            for i in 0..<count {
                XCTAssertEqual(result.records[0].frames[i], UInt(i + 1), "frame \(i)")
            }
        }

        func test_frameData_multipleRecords_eachCorrect() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            let recordDefs: [(ts: UInt64, frames: [UInt])] = [
                (1_000, [10, 20, 30]),
                (2_000, [0xAAAA, 0xBBBB]),
                (3_000, []),
                (4_000, [UInt.max, 0, 1]),
                (5_000, [42])
            ]

            for def in recordDefs {
                emb_ring_buffer_write(buf, def.ts, def.frames, def.frames.count)
            }

            var result = emb_ring_buffer_read_range(buf, 0, UINT64_MAX)
            defer { emb_ring_read_result_free(&result) }

            XCTAssertEqual(result.count, recordDefs.count)
            for i in 0..<result.count {
                let rec = result.records[i]
                let def = recordDefs[i]
                XCTAssertEqual(rec.timestamp_ns, def.ts, "record \(i) timestamp")
                XCTAssertEqual(rec.frame_count, def.frames.count, "record \(i) frame_count")
                for j in 0..<def.frames.count {
                    XCTAssertEqual(rec.frames[j], def.frames[j], "record \(i) frame \(j)")
                }
            }
        }

        // MARK: - Eviction edge cases

        func test_eviction_exactFit_noEviction() {
            // 1-frame records: 32 bytes each.  4096 / 32 = 128 fit exactly.
            let page = Int(getpagesize())
            let buf = emb_ring_buffer_create(page)!
            defer { emb_ring_buffer_destroy(buf) }

            let rSize = RingBufferEdgeCaseTests.recordSize(1)
            let fits = page / rSize

            for i in 0..<fits {
                let f: [UInt] = [UInt(i + 1)]
                emb_ring_buffer_write(buf, UInt64(i + 1), f, 1)
            }

            var result = emb_ring_buffer_read_range(buf, 0, UINT64_MAX)
            defer { emb_ring_read_result_free(&result) }

            XCTAssertEqual(result.count, fits, "all \(fits) records must fit without eviction")
            XCTAssertEqual(result.records[0].timestamp_ns, 1)
            XCTAssertEqual(result.records[fits - 1].timestamp_ns, UInt64(fits))
        }

        func test_eviction_onePastCapacity_evictsOldest() {
            let page = Int(getpagesize())
            let buf = emb_ring_buffer_create(page)!
            defer { emb_ring_buffer_destroy(buf) }

            let rSize = RingBufferEdgeCaseTests.recordSize(1)
            let fits = page / rSize

            for i in 0..<fits {
                let f: [UInt] = [UInt(i + 1)]
                emb_ring_buffer_write(buf, UInt64(i + 1), f, 1)
            }

            // One more triggers eviction of record 1 (ts=1).
            let f: [UInt] = [0xBEEF]
            emb_ring_buffer_write(buf, UInt64(fits + 1), f, 1)

            var result = emb_ring_buffer_read_range(buf, 0, UINT64_MAX)
            defer { emb_ring_read_result_free(&result) }

            XCTAssertEqual(result.count, fits)
            XCTAssertEqual(
                result.records[0].timestamp_ns, 2,
                "record with ts=1 should be evicted")
            XCTAssertEqual(result.records[fits - 1].timestamp_ns, UInt64(fits + 1))
        }

        func test_eviction_largeRecordEvictsMultipleSmallOnes() {
            let page = Int(getpagesize())
            let buf = emb_ring_buffer_create(page)!
            defer { emb_ring_buffer_destroy(buf) }

            // Fill with 1-frame (24-byte) records.
            let smallCount = page / RingBufferEdgeCaseTests.recordSize(1)
            for i in 0..<smallCount {
                let f: [UInt] = [UInt(i + 1)]
                emb_ring_buffer_write(buf, UInt64(i + 1) * 100, f, 1)
            }

            var before = emb_ring_buffer_read_range(buf, 0, UINT64_MAX)
            let cntBefore = before.count
            emb_ring_read_result_free(&before)
            XCTAssertEqual(cntBefore, smallCount)

            // Write one large record (50 frames = 416 bytes).
            // It must evict ceil(416/24) ≈ 18 small records before fitting.
            let largeFC = 50
            let largeFrames = [UInt](repeating: 0xDEAD, count: largeFC)
            let largeTS: UInt64 = UInt64(smallCount + 1) * 100
            emb_ring_buffer_write(buf, largeTS, largeFrames, largeFC)

            var after = emb_ring_buffer_read_range(buf, 0, UINT64_MAX)
            defer { emb_ring_read_result_free(&after) }

            XCTAssertLessThan(
                after.count, smallCount + 1,
                "large write must have evicted some small records")

            let last = after.records[after.count - 1]
            XCTAssertEqual(last.timestamp_ns, largeTS)
            XCTAssertEqual(last.frame_count, largeFC)
            for j in 0..<largeFC {
                XCTAssertEqual(last.frames[j], 0xDEAD, "frame \(j)")
            }
        }

        func test_eviction_zeroFrameRecords_evictedCorrectly() {
            let page = Int(getpagesize())
            let buf = emb_ring_buffer_create(page)!
            defer { emb_ring_buffer_destroy(buf) }

            // Zero-frame records are 16 bytes (header only). 4096/16 = 256 fit.
            let zeroSize = RingBufferEdgeCaseTests.headerSize
            let zeroCount = page / zeroSize

            let empty: [UInt] = []
            for i in 0..<zeroCount {
                emb_ring_buffer_write(buf, UInt64(i + 1) * 100, empty, 0)
            }

            var before = emb_ring_buffer_read_range(buf, 0, UINT64_MAX)
            let cntBefore = before.count
            emb_ring_read_result_free(&before)
            XCTAssertEqual(cntBefore, zeroCount)

            // Write one more zero-frame record — evicts the oldest.
            emb_ring_buffer_write(buf, UInt64(zeroCount + 1) * 100, empty, 0)

            var after = emb_ring_buffer_read_range(buf, 0, UINT64_MAX)
            defer { emb_ring_read_result_free(&after) }

            XCTAssertEqual(after.count, zeroCount)
            XCTAssertEqual(
                after.records[0].timestamp_ns, 200,
                "oldest (ts=100) should be evicted; next is ts=200")
        }

        func test_eviction_bufferRemainsFunctionalAfterManyPasses() {
            let page = Int(getpagesize())
            let buf = emb_ring_buffer_create(page)!
            defer { emb_ring_buffer_destroy(buf) }

            let rSize = RingBufferEdgeCaseTests.recordSize(10)
            let perPage = page / rSize
            let totalWrites = perPage * 5  // five complete passes

            for i in 0..<totalWrites {
                let f = [UInt](repeating: UInt(i + 1), count: 10)
                emb_ring_buffer_write(buf, UInt64(i + 1), f, 10)
            }

            var result = emb_ring_buffer_read_range(buf, 0, UINT64_MAX)
            defer { emb_ring_read_result_free(&result) }

            XCTAssertGreaterThan(result.count, 0)
            XCTAssertLessThanOrEqual(result.count, perPage + 1)

            // All surviving timestamps come from the final pass.
            let finalPassStart = UInt64(perPage * 4)
            for i in 0..<result.count {
                XCTAssertGreaterThan(
                    result.records[i].timestamp_ns, finalPassStart,
                    "record \(i) should be from the last two passes")
            }
        }

        func test_eviction_mixedSizes_oldestEvictedFirst() {
            let page = Int(getpagesize())
            let buf = emb_ring_buffer_create(page)!
            defer { emb_ring_buffer_destroy(buf) }

            var ts: UInt64 = 0

            // Write alternating small (1 frame, 24 B) and large (20 frames, 176 B).
            let smallFC = 1
            let largeFC = 20
            let smallSz = RingBufferEdgeCaseTests.recordSize(smallFC)
            let largeSz = RingBufferEdgeCaseTests.recordSize(largeFC)

            var totalBytes = 0
            while totalBytes + smallSz <= page {
                ts += 1
                let f: [UInt] = [UInt(ts)]
                emb_ring_buffer_write(buf, ts, f, smallFC)
                totalBytes += smallSz

                if totalBytes + largeSz <= page {
                    ts += 1
                    let lf = [UInt](repeating: UInt(ts), count: largeFC)
                    emb_ring_buffer_write(buf, ts, lf, largeFC)
                    totalBytes += largeSz
                }
            }

            let firstTS: UInt64 = 1

            // Trigger eviction.
            ts += 1
            let extra: [UInt] = [UInt(ts)]
            emb_ring_buffer_write(buf, ts, extra, smallFC)

            var result = emb_ring_buffer_read_range(buf, 0, UINT64_MAX)
            defer { emb_ring_read_result_free(&result) }

            XCTAssertGreaterThan(
                result.records[0].timestamp_ns, firstTS,
                "oldest record must be evicted")

            for i in 1..<result.count {
                XCTAssertGreaterThan(
                    result.records[i].timestamp_ns,
                    result.records[i - 1].timestamp_ns,
                    "timestamps must be strictly ascending after eviction")
            }
        }

        func test_eviction_evictedRecord_notVisibleInTimestampQuery() {
            let page = Int(getpagesize())
            let buf = emb_ring_buffer_create(page)!
            defer { emb_ring_buffer_destroy(buf) }

            let rSize = RingBufferEdgeCaseTests.recordSize(1)
            let fits = page / rSize

            // Fill, then write one more to evict ts=1.
            for i in 0...fits {  // fits+1 writes
                let f: [UInt] = [UInt(i + 1)]
                emb_ring_buffer_write(buf, UInt64(i + 1), f, 1)
            }

            // Querying exactly for the evicted timestamp should return nothing.
            var evicted = emb_ring_buffer_read_range(buf, 1, 1)
            defer { emb_ring_read_result_free(&evicted) }
            XCTAssertEqual(evicted.count, 0, "evicted record should not appear in range query")
        }

        // MARK: - Timestamp range edge cases

        func test_readRange_exactStartBoundary_included() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            for ts: UInt64 in [100, 200, 300, 400, 500] {
                let f: [UInt] = [UInt(ts)]
                emb_ring_buffer_write(buf, ts, f, 1)
            }

            var result = emb_ring_buffer_read_range(buf, 300, UINT64_MAX)
            defer { emb_ring_read_result_free(&result) }

            XCTAssertEqual(result.count, 3)
            XCTAssertEqual(result.records[0].timestamp_ns, 300)
            XCTAssertEqual(result.records[1].timestamp_ns, 400)
            XCTAssertEqual(result.records[2].timestamp_ns, 500)
        }

        func test_readRange_exactEndBoundary_included() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            for ts: UInt64 in [100, 200, 300, 400, 500] {
                let f: [UInt] = [UInt(ts)]
                emb_ring_buffer_write(buf, ts, f, 1)
            }

            var result = emb_ring_buffer_read_range(buf, 0, 300)
            defer { emb_ring_read_result_free(&result) }

            XCTAssertEqual(result.count, 3)
            XCTAssertEqual(result.records[0].timestamp_ns, 100)
            XCTAssertEqual(result.records[1].timestamp_ns, 200)
            XCTAssertEqual(result.records[2].timestamp_ns, 300)
        }

        func test_readRange_startEqualsEnd_matchingRecord_returnsOne() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            for ts: UInt64 in [100, 200, 300] {
                let f: [UInt] = [UInt(ts)]
                emb_ring_buffer_write(buf, ts, f, 1)
            }

            var result = emb_ring_buffer_read_range(buf, 200, 200)
            defer { emb_ring_read_result_free(&result) }

            XCTAssertEqual(result.count, 1)
            XCTAssertEqual(result.records[0].timestamp_ns, 200)
        }

        func test_readRange_startEqualsEnd_noMatchingRecord_returnsEmpty() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            for ts: UInt64 in [100, 200, 300] {
                let f: [UInt] = [1]
                emb_ring_buffer_write(buf, ts, f, 1)
            }

            var result = emb_ring_buffer_read_range(buf, 150, 150)
            defer { emb_ring_read_result_free(&result) }

            XCTAssertEqual(result.count, 0)
        }

        func test_readRange_startGreaterThanEnd_returnsEmpty() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            for ts: UInt64 in [100, 200, 300] {
                let f: [UInt] = [1]
                emb_ring_buffer_write(buf, ts, f, 1)
            }

            var result = emb_ring_buffer_read_range(buf, 500, 100)
            defer { emb_ring_read_result_free(&result) }

            XCTAssertEqual(result.count, 0)
        }

        func test_readRange_allRecordsBeforeStart_returnsEmpty() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            for ts: UInt64 in [100, 200, 300] {
                let f: [UInt] = [1]
                emb_ring_buffer_write(buf, ts, f, 1)
            }

            var result = emb_ring_buffer_read_range(buf, 400, UINT64_MAX)
            defer { emb_ring_read_result_free(&result) }

            XCTAssertEqual(result.count, 0)
        }

        func test_readRange_allRecordsAfterEnd_returnsEmpty() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            for ts: UInt64 in [400, 500, 600] {
                let f: [UInt] = [1]
                emb_ring_buffer_write(buf, ts, f, 1)
            }

            var result = emb_ring_buffer_read_range(buf, 0, 300)
            defer { emb_ring_read_result_free(&result) }

            XCTAssertEqual(result.count, 0)
        }

        func test_readRange_gapBetweenRecords_returnsEmpty() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            // Records at 100 and 300; query [150, 250] falls in the gap.
            for ts: UInt64 in [100, 300] {
                let f: [UInt] = [1]
                emb_ring_buffer_write(buf, ts, f, 1)
            }

            var result = emb_ring_buffer_read_range(buf, 150, 250)
            defer { emb_ring_read_result_free(&result) }

            XCTAssertEqual(result.count, 0)
        }

        func test_readRange_duplicateTimestamps_allReturned() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            let sharedTS: UInt64 = 99_999
            for i in 0..<7 {
                let f: [UInt] = [UInt(i + 1)]
                emb_ring_buffer_write(buf, sharedTS, f, 1)
            }

            var result = emb_ring_buffer_read_range(buf, sharedTS, sharedTS)
            defer { emb_ring_read_result_free(&result) }

            XCTAssertEqual(result.count, 7)
            for i in 0..<result.count {
                XCTAssertEqual(result.records[i].timestamp_ns, sharedTS)
            }
        }

        func test_readRange_timestampZero_matchedByZeroStart() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            let f: [UInt] = [0xABCD]
            emb_ring_buffer_write(buf, 0, f, 1)

            var result = emb_ring_buffer_read_range(buf, 0, 0)
            defer { emb_ring_read_result_free(&result) }

            XCTAssertEqual(result.count, 1)
            XCTAssertEqual(result.records[0].timestamp_ns, 0)
            XCTAssertEqual(result.records[0].frames[0], 0xABCD)
        }

        func test_readRange_timestampMaxUInt64_matchedByMaxEnd() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            let f: [UInt] = [0x1234]
            emb_ring_buffer_write(buf, UINT64_MAX, f, 1)

            var result = emb_ring_buffer_read_range(buf, UINT64_MAX, UINT64_MAX)
            defer { emb_ring_read_result_free(&result) }

            XCTAssertEqual(result.count, 1)
            XCTAssertEqual(result.records[0].timestamp_ns, UINT64_MAX)
        }

        func test_readRange_singleRecordInLargeSet() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            for i in 1...20 {
                let f: [UInt] = [UInt(i)]
                emb_ring_buffer_write(buf, UInt64(i) * 1_000, f, 1)
            }

            // Only timestamp 11_000 (i=11) is in range [11000, 11000].
            var result = emb_ring_buffer_read_range(buf, 11_000, 11_000)
            defer { emb_ring_read_result_free(&result) }

            XCTAssertEqual(result.count, 1)
            XCTAssertEqual(result.records[0].timestamp_ns, 11_000)
            XCTAssertEqual(result.records[0].frames[0], 11)
        }

        func test_readRange_nilBuffer_returnsEmptyResult() {
            let result = emb_ring_buffer_read_range(nil, 0, UINT64_MAX)
            XCTAssertEqual(result.count, 0)
            XCTAssertNil(result.records)
        }

        func test_readRange_subsetInMiddle() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            for i in 1...20 {
                let f: [UInt] = [UInt(i)]
                emb_ring_buffer_write(buf, UInt64(i) * 1_000, f, 1)
            }

            // Range [5000, 10000] should return records at 5000..10000 inclusive.
            var result = emb_ring_buffer_read_range(buf, 5_000, 10_000)
            defer { emb_ring_read_result_free(&result) }

            XCTAssertEqual(result.count, 6)
            for i in 0..<result.count {
                XCTAssertEqual(result.records[i].timestamp_ns, UInt64(i + 5) * 1_000)
            }
        }

        // MARK: - Read result integrity

        func test_readResult_freeNilRecords_doesNotCrash() {
            var zero = emb_ring_read_result_t(records: nil, count: 0)
            emb_ring_read_result_free(&zero)
        }

        func test_readResult_free_clearsFieldsToZero() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            let f: [UInt] = [1, 2, 3]
            emb_ring_buffer_write(buf, 1_000, f, f.count)

            var result = emb_ring_buffer_read_range(buf, 0, UINT64_MAX)
            XCTAssertNotNil(result.records)
            XCTAssertGreaterThan(result.count, 0)

            emb_ring_read_result_free(&result)
            XCTAssertNil(result.records)
            XCTAssertEqual(result.count, 0)
        }

        func test_readResult_consecutiveCalls_identicalData() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            for i in 1...5 {
                let f: [UInt] = [UInt(i * 10), UInt(i * 10 + 1)]
                emb_ring_buffer_write(buf, UInt64(i) * 1_000, f, 2)
            }

            var r1 = emb_ring_buffer_read_range(buf, 0, UINT64_MAX)
            var r2 = emb_ring_buffer_read_range(buf, 0, UINT64_MAX)
            defer {
                emb_ring_read_result_free(&r1)
                emb_ring_read_result_free(&r2)
            }

            XCTAssertEqual(r1.count, r2.count)
            for i in 0..<r1.count {
                XCTAssertEqual(r1.records[i].timestamp_ns, r2.records[i].timestamp_ns)
                XCTAssertEqual(r1.records[i].frame_count, r2.records[i].frame_count)
                for j in 0..<r1.records[i].frame_count {
                    XCTAssertEqual(
                        r1.records[i].frames[j], r2.records[i].frames[j],
                        "record \(i) frame \(j)")
                }
            }
        }

        func test_readResult_framesPointerWithinAllocation() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            let f: [UInt] = [0xA, 0xB, 0xC]
            emb_ring_buffer_write(buf, 1_000, f, f.count)

            var result = emb_ring_buffer_read_range(buf, 0, UINT64_MAX)
            defer { emb_ring_read_result_free(&result) }

            XCTAssertEqual(result.count, 1)
            let recBase = Int(bitPattern: UnsafeRawPointer(result.records))
            let framesPtr = Int(bitPattern: UnsafeRawPointer(result.records[0].frames))

            // frames must lie after the record array, within a reasonable range.
            XCTAssertGreaterThan(framesPtr, recBase)
            XCTAssertLessThan(framesPtr - recBase, 65_536)
        }

        func test_readResult_timestampsMonotonicallyIncreasing() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            for i in 1...30 {
                let f: [UInt] = [UInt(i)]
                emb_ring_buffer_write(buf, UInt64(i) * 100_000_000, f, 1)
            }

            var result = emb_ring_buffer_read_range(buf, 0, UINT64_MAX)
            defer { emb_ring_read_result_free(&result) }

            for i in 1..<result.count {
                XCTAssertGreaterThan(
                    result.records[i].timestamp_ns,
                    result.records[i - 1].timestamp_ns,
                    "timestamps must be strictly increasing")
            }
        }

        // MARK: - Wrap-around

        func test_wrapAround_recordStraddlingCapacityBoundary_readableAndCorrect() {
            let page = Int(getpagesize())
            let buf = emb_ring_buffer_create(page)!
            defer { emb_ring_buffer_destroy(buf) }

            let capacity = Int(buf.pointee.capacity)
            // 3-frame records = 40 bytes.  Fill until the next write would straddle.
            let rSize = RingBufferEdgeCaseTests.recordSize(3)
            var total = 0
            var ts: UInt64 = 0

            while total + rSize <= capacity {
                ts += 1
                let f: [UInt] = [UInt(ts), UInt(ts + 1), UInt(ts + 2)]
                emb_ring_buffer_write(buf, ts, f, 3)
                total += rSize
            }

            // Remaining space at end of buffer.
            let remaining = capacity - (total % capacity)
            let willStraddle = remaining > 0 && remaining < rSize

            ts += 1
            let straddle: [UInt] = [UInt(ts), UInt(ts + 1), UInt(ts + 2)]
            let ok = emb_ring_buffer_write(buf, ts, straddle, 3)
            XCTAssertTrue(ok, "write straddling boundary must succeed")

            var result = emb_ring_buffer_read_range(buf, ts, ts)
            defer { emb_ring_read_result_free(&result) }

            if willStraddle {
                XCTAssertEqual(result.count, 1, "straddling record must be readable")
                XCTAssertEqual(result.records[0].frames[0], UInt(ts))
                XCTAssertEqual(result.records[0].frames[1], UInt(ts + 1))
                XCTAssertEqual(result.records[0].frames[2], UInt(ts + 2))
            } else {
                // Didn't straddle this time due to alignment, but write still succeeded.
                XCTAssertTrue(ok)
            }
        }

        func test_wrapAround_multiplePasses_onlyRecentRecordsVisible() {
            let page = Int(getpagesize())
            let buf = emb_ring_buffer_create(page)!
            defer { emb_ring_buffer_destroy(buf) }

            let rSize = RingBufferEdgeCaseTests.recordSize(5)
            let perPage = page / rSize
            let total = perPage * 5

            for i in 0..<total {
                let f = [UInt](repeating: UInt(i + 1), count: 5)
                emb_ring_buffer_write(buf, UInt64(i + 1), f, 5)
            }

            var result = emb_ring_buffer_read_range(buf, 0, UINT64_MAX)
            defer { emb_ring_read_result_free(&result) }

            XCTAssertGreaterThan(result.count, 0)
            XCTAssertLessThanOrEqual(result.count, perPage + 1)

            // Every surviving record's frames must match the write pattern: frame[j] = ts.
            for i in 0..<result.count {
                let ts = result.records[i].timestamp_ns
                for j in 0..<result.records[i].frame_count {
                    XCTAssertEqual(
                        result.records[i].frames[j], UInt(ts),
                        "record \(i) frame \(j): expected \(ts)")
                }
            }

            // Timestamps are strictly ascending.
            for i in 1..<result.count {
                XCTAssertGreaterThan(
                    result.records[i].timestamp_ns,
                    result.records[i - 1].timestamp_ns)
            }
        }

        func test_wrapAround_variableFrameCounts_frameDataCorrect() {
            let buf = emb_ring_buffer_create(4 * Int(getpagesize()))!
            defer { emb_ring_buffer_destroy(buf) }

            // Write records with frame counts cycling 0,1,2,...,15,0,1,...
            let n = 200
            var defs: [(ts: UInt64, fc: Int, sentinel: UInt)] = []
            for i in 0..<n {
                let fc = i % 16
                let ts = UInt64(i + 1) * 1_000
                let sentinel = UInt(i + 1) * 0x10000
                defs.append((ts, fc, sentinel))

                if fc == 0 {
                    let empty: [UInt] = []
                    emb_ring_buffer_write(buf, ts, empty, 0)
                } else {
                    let f = (0..<fc).map { UInt(sentinel) + UInt($0) }
                    emb_ring_buffer_write(buf, ts, f, fc)
                }
            }

            var result = emb_ring_buffer_read_range(buf, 0, UINT64_MAX)
            defer { emb_ring_read_result_free(&result) }

            XCTAssertGreaterThan(result.count, 0)

            for i in 0..<result.count {
                let rec = result.records[i]
                // Find matching def by timestamp.
                guard let def = defs.first(where: { $0.ts == rec.timestamp_ns }) else {
                    XCTFail("unknown timestamp \(rec.timestamp_ns)")
                    continue
                }
                XCTAssertEqual(rec.frame_count, def.fc, "ts=\(def.ts) frame_count")
                for j in 0..<def.fc {
                    XCTAssertEqual(
                        rec.frames[j], def.sentinel + UInt(j),
                        "ts=\(def.ts) frame \(j)")
                }
            }
        }
    }

#endif
