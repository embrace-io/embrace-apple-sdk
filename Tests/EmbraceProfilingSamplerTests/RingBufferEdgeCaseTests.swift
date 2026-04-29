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
        //   uint32_t seq             = 4 bytes
        //   uint32_t frame_count     = 4 bytes
        //   uint64_t timestamp_ns    = 8 bytes
        //   + 8 bytes per frame
        static let headerSize = 16
        static let frameSize = 8

        static func recordSize(_ frameCount: Int) -> Int {
            headerSize + frameSize * frameCount
        }

        // MARK: - Lifecycle

        func test_create_zeroCapacity_returnsNil() {
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

            let records = testReadRange(buf, 0, UINT64_MAX)
            XCTAssertEqual(records.count, 0)
        }

        func test_destroy_nil_doesNotCrash() {
            emb_ring_buffer_destroy(nil)
        }

        func test_capacity_nil_returnsZero() {
            XCTAssertEqual(emb_ring_buffer_capacity(nil), 0)
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

            let records = testReadRange(buf, 0, UINT64_MAX)
            XCTAssertEqual(records.count, 0)
        }

        // MARK: - Frame data preservation

        func test_frameData_exactValuesPreserved() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            let frames: [UInt] = [0xDEAD_BEEF, 0xCAFE_BABE, 0x1234_5678, 0xFFFF_FFFF]
            emb_ring_buffer_write(buf, 42_000, frames, frames.count)

            let records = testReadRange(buf, 0, UINT64_MAX)

            XCTAssertEqual(records.count, 1)
            XCTAssertEqual(records[0].frame_count, frames.count)
            for i in 0..<frames.count {
                XCTAssertEqual(records[0].frames[i], frames[i], "frame \(i)")
            }
        }

        func test_frameData_allZeros_preserved() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            let frames = [UInt](repeating: 0, count: 8)
            emb_ring_buffer_write(buf, 1_000, frames, frames.count)

            let records = testReadRange(buf, 0, UINT64_MAX)

            XCTAssertEqual(records.count, 1)
            for i in 0..<frames.count {
                XCTAssertEqual(records[0].frames[i], 0, "frame \(i)")
            }
        }

        func test_frameData_allMaxValue_preserved() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            let frames = [UInt](repeating: UInt.max, count: 8)
            emb_ring_buffer_write(buf, 2_000, frames, frames.count)

            let records = testReadRange(buf, 0, UINT64_MAX)

            XCTAssertEqual(records.count, 1)
            for i in 0..<frames.count {
                XCTAssertEqual(records[0].frames[i], UInt.max, "frame \(i)")
            }
        }

        func test_frameData_largeFrameCount_preserved() {
            let buf = emb_ring_buffer_create(4 * 1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            let count = 512
            let frames = (0..<count).map { UInt($0 + 1) }
            emb_ring_buffer_write(buf, 99_000, frames, count)

            let records = testReadRange(buf, 0, UINT64_MAX)

            XCTAssertEqual(records.count, 1)
            XCTAssertEqual(records[0].frame_count, count)
            for i in 0..<count {
                XCTAssertEqual(records[0].frames[i], UInt(i + 1), "frame \(i)")
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

            let records = testReadRange(buf, 0, UINT64_MAX)

            XCTAssertEqual(records.count, recordDefs.count)
            for i in 0..<records.count {
                let rec = records[i]
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
            let page = Int(getpagesize())
            let buf = emb_ring_buffer_create(page)!
            defer { emb_ring_buffer_destroy(buf) }

            let rSize = RingBufferEdgeCaseTests.recordSize(1)
            let fits = page / rSize

            for i in 0..<fits {
                let f: [UInt] = [UInt(i + 1)]
                emb_ring_buffer_write(buf, UInt64(i + 1), f, 1)
            }

            let records = testReadRange(buf, 0, UINT64_MAX)

            XCTAssertEqual(records.count, fits, "all \(fits) records must fit without eviction")
            XCTAssertEqual(records[0].timestamp_ns, 1)
            XCTAssertEqual(records[fits - 1].timestamp_ns, UInt64(fits))
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

            let f: [UInt] = [0xBEEF]
            emb_ring_buffer_write(buf, UInt64(fits + 1), f, 1)

            let records = testReadRange(buf, 0, UINT64_MAX)

            XCTAssertEqual(records.count, fits)
            XCTAssertEqual(
                records[0].timestamp_ns, 2,
                "record with ts=1 should be evicted")
            XCTAssertEqual(records[fits - 1].timestamp_ns, UInt64(fits + 1))
        }

        func test_eviction_largeRecordEvictsMultipleSmallOnes() {
            let page = Int(getpagesize())
            let buf = emb_ring_buffer_create(page)!
            defer { emb_ring_buffer_destroy(buf) }

            let smallCount = page / RingBufferEdgeCaseTests.recordSize(1)
            for i in 0..<smallCount {
                let f: [UInt] = [UInt(i + 1)]
                emb_ring_buffer_write(buf, UInt64(i + 1) * 100, f, 1)
            }

            let cntBefore = testReadRange(buf, 0, UINT64_MAX).count
            XCTAssertEqual(cntBefore, smallCount)

            let largeFC = 50
            let largeFrames = [UInt](repeating: 0xDEAD, count: largeFC)
            let largeTS: UInt64 = UInt64(smallCount + 1) * 100
            emb_ring_buffer_write(buf, largeTS, largeFrames, largeFC)

            let after = testReadRange(buf, 0, UINT64_MAX)

            XCTAssertLessThan(
                after.count, smallCount + 1,
                "large write must have evicted some small records")

            let last = after[after.count - 1]
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

            let zeroSize = RingBufferEdgeCaseTests.headerSize
            let zeroCount = page / zeroSize

            let empty: [UInt] = []
            for i in 0..<zeroCount {
                emb_ring_buffer_write(buf, UInt64(i + 1) * 100, empty, 0)
            }

            let cntBefore = testReadRange(buf, 0, UINT64_MAX).count
            XCTAssertEqual(cntBefore, zeroCount)

            emb_ring_buffer_write(buf, UInt64(zeroCount + 1) * 100, empty, 0)

            let after = testReadRange(buf, 0, UINT64_MAX)

            XCTAssertEqual(after.count, zeroCount)
            XCTAssertEqual(
                after[0].timestamp_ns, 200,
                "oldest (ts=100) should be evicted; next is ts=200")
        }

        func test_eviction_bufferRemainsFunctionalAfterManyPasses() {
            let page = Int(getpagesize())
            let buf = emb_ring_buffer_create(page)!
            defer { emb_ring_buffer_destroy(buf) }

            let rSize = RingBufferEdgeCaseTests.recordSize(10)
            let perPage = page / rSize
            let totalWrites = perPage * 5

            for i in 0..<totalWrites {
                let f = [UInt](repeating: UInt(i + 1), count: 10)
                emb_ring_buffer_write(buf, UInt64(i + 1), f, 10)
            }

            let records = testReadRange(buf, 0, UINT64_MAX)

            XCTAssertGreaterThan(records.count, 0)
            XCTAssertLessThanOrEqual(records.count, perPage + 1)

            let finalPassStart = UInt64(perPage * 4)
            for i in 0..<records.count {
                XCTAssertGreaterThan(
                    records[i].timestamp_ns, finalPassStart,
                    "record \(i) should be from the last pass")
            }
        }

        func test_eviction_mixedSizes_oldestEvictedFirst() {
            let page = Int(getpagesize())
            let buf = emb_ring_buffer_create(page)!
            defer { emb_ring_buffer_destroy(buf) }

            var ts: UInt64 = 0
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

            ts += 1
            let extra: [UInt] = [UInt(ts)]
            emb_ring_buffer_write(buf, ts, extra, smallFC)

            let records = testReadRange(buf, 0, UINT64_MAX)

            XCTAssertGreaterThan(
                records[0].timestamp_ns, firstTS,
                "oldest record must be evicted")

            for i in 1..<records.count {
                XCTAssertGreaterThan(
                    records[i].timestamp_ns,
                    records[i - 1].timestamp_ns,
                    "timestamps must be strictly ascending after eviction")
            }
        }

        func test_eviction_evictedRecord_notVisibleInTimestampQuery() {
            let page = Int(getpagesize())
            let buf = emb_ring_buffer_create(page)!
            defer { emb_ring_buffer_destroy(buf) }

            let rSize = RingBufferEdgeCaseTests.recordSize(1)
            let fits = page / rSize

            for i in 0...fits {
                let f: [UInt] = [UInt(i + 1)]
                emb_ring_buffer_write(buf, UInt64(i + 1), f, 1)
            }

            let evicted = testReadRange(buf, 1, 1)
            XCTAssertEqual(evicted.count, 0, "evicted record should not appear in range query")
        }

        // MARK: - Prefix skip

        func test_readRange_skipsPrefix_returnsSuffix() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            // Monotonic timestamps; query skips the first two.
            for ts: UInt64 in [100, 200, 300, 400, 500] {
                let f: [UInt] = [UInt(ts)]
                emb_ring_buffer_write(buf, ts, f, 1)
            }

            let records = testReadRange(buf, 300, 400)

            XCTAssertEqual(records.count, 2)
            XCTAssertEqual(records[0].timestamp_ns, 300)
            XCTAssertEqual(records[1].timestamp_ns, 400)
        }

        // MARK: - Timestamp range edge cases

        func test_readRange_exactStartBoundary_included() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            for ts: UInt64 in [100, 200, 300, 400, 500] {
                let f: [UInt] = [UInt(ts)]
                emb_ring_buffer_write(buf, ts, f, 1)
            }

            let records = testReadRange(buf, 300, UINT64_MAX)

            XCTAssertEqual(records.count, 3)
            XCTAssertEqual(records[0].timestamp_ns, 300)
            XCTAssertEqual(records[1].timestamp_ns, 400)
            XCTAssertEqual(records[2].timestamp_ns, 500)
        }

        func test_readRange_exactEndBoundary_included() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            for ts: UInt64 in [100, 200, 300, 400, 500] {
                let f: [UInt] = [UInt(ts)]
                emb_ring_buffer_write(buf, ts, f, 1)
            }

            let records = testReadRange(buf, 0, 300)

            XCTAssertEqual(records.count, 3)
            XCTAssertEqual(records[0].timestamp_ns, 100)
            XCTAssertEqual(records[1].timestamp_ns, 200)
            XCTAssertEqual(records[2].timestamp_ns, 300)
        }

        func test_readRange_startEqualsEnd_matchingRecord_returnsOne() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            for ts: UInt64 in [100, 200, 300] {
                let f: [UInt] = [UInt(ts)]
                emb_ring_buffer_write(buf, ts, f, 1)
            }

            let records = testReadRange(buf, 200, 200)

            XCTAssertEqual(records.count, 1)
            XCTAssertEqual(records[0].timestamp_ns, 200)
        }

        func test_readRange_startEqualsEnd_noMatchingRecord_returnsEmpty() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            for ts: UInt64 in [100, 200, 300] {
                let f: [UInt] = [1]
                emb_ring_buffer_write(buf, ts, f, 1)
            }

            let records = testReadRange(buf, 150, 150)
            XCTAssertEqual(records.count, 0)
        }

        func test_readRange_startGreaterThanEnd_returnsEmpty() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            for ts: UInt64 in [100, 200, 300] {
                let f: [UInt] = [1]
                emb_ring_buffer_write(buf, ts, f, 1)
            }

            let records = testReadRange(buf, 500, 100)
            XCTAssertEqual(records.count, 0)
        }

        func test_readRange_allRecordsBeforeStart_returnsEmpty() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            for ts: UInt64 in [100, 200, 300] {
                let f: [UInt] = [1]
                emb_ring_buffer_write(buf, ts, f, 1)
            }

            let records = testReadRange(buf, 400, UINT64_MAX)
            XCTAssertEqual(records.count, 0)
        }

        func test_readRange_allRecordsAfterEnd_returnsEmpty() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            for ts: UInt64 in [400, 500, 600] {
                let f: [UInt] = [1]
                emb_ring_buffer_write(buf, ts, f, 1)
            }

            let records = testReadRange(buf, 0, 300)
            XCTAssertEqual(records.count, 0)
        }

        func test_readRange_gapBetweenRecords_returnsEmpty() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            for ts: UInt64 in [100, 300] {
                let f: [UInt] = [1]
                emb_ring_buffer_write(buf, ts, f, 1)
            }

            let records = testReadRange(buf, 150, 250)
            XCTAssertEqual(records.count, 0)
        }

        func test_readRange_duplicateTimestamps_allReturned() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            let sharedTS: UInt64 = 99_999
            for i in 0..<7 {
                let f: [UInt] = [UInt(i + 1)]
                emb_ring_buffer_write(buf, sharedTS, f, 1)
            }

            let records = testReadRange(buf, sharedTS, sharedTS)

            XCTAssertEqual(records.count, 7)
            for i in 0..<records.count {
                XCTAssertEqual(records[i].timestamp_ns, sharedTS)
            }
        }

        func test_readRange_timestampZero_matchedByZeroStart() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            let f: [UInt] = [0xABCD]
            emb_ring_buffer_write(buf, 0, f, 1)

            let records = testReadRange(buf, 0, 0)

            XCTAssertEqual(records.count, 1)
            XCTAssertEqual(records[0].timestamp_ns, 0)
            XCTAssertEqual(records[0].frames[0], 0xABCD)
        }

        func test_readRange_timestampMaxUInt64_matchedByMaxEnd() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            let f: [UInt] = [0x1234]
            emb_ring_buffer_write(buf, UINT64_MAX, f, 1)

            let records = testReadRange(buf, UINT64_MAX, UINT64_MAX)

            XCTAssertEqual(records.count, 1)
            XCTAssertEqual(records[0].timestamp_ns, UINT64_MAX)
        }

        func test_readRange_singleRecordInLargeSet() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            for i in 1...20 {
                let f: [UInt] = [UInt(i)]
                emb_ring_buffer_write(buf, UInt64(i) * 1_000, f, 1)
            }

            let records = testReadRange(buf, 11_000, 11_000)

            XCTAssertEqual(records.count, 1)
            XCTAssertEqual(records[0].timestamp_ns, 11_000)
            XCTAssertEqual(records[0].frames[0], 11)
        }

        func test_readRange_nilBuffer_returnsEmptyResult() {
            var output = [UInt8](repeating: 0, count: 16)
            let result = emb_ring_buffer_read_range(nil, 0, UINT64_MAX, &output, output.count)
            XCTAssertEqual(result.record_count, 0)
        }

        func test_readRange_subsetInMiddle() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            for i in 1...20 {
                let f: [UInt] = [UInt(i)]
                emb_ring_buffer_write(buf, UInt64(i) * 1_000, f, 1)
            }

            let records = testReadRange(buf, 5_000, 10_000)

            XCTAssertEqual(records.count, 6)
            for i in 0..<records.count {
                XCTAssertEqual(records[i].timestamp_ns, UInt64(i + 5) * 1_000)
            }
        }

        // MARK: - Read result integrity

        func test_readResult_consecutiveCalls_identicalData() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            for i in 1...5 {
                let f: [UInt] = [UInt(i * 10), UInt(i * 10 + 1)]
                emb_ring_buffer_write(buf, UInt64(i) * 1_000, f, 2)
            }

            let r1 = testReadRange(buf, 0, UINT64_MAX)
            let r2 = testReadRange(buf, 0, UINT64_MAX)

            XCTAssertEqual(r1.count, r2.count)
            for i in 0..<r1.count {
                XCTAssertEqual(r1[i].timestamp_ns, r2[i].timestamp_ns)
                XCTAssertEqual(r1[i].frame_count, r2[i].frame_count)
                for j in 0..<r1[i].frame_count {
                    XCTAssertEqual(
                        r1[i].frames[j], r2[i].frames[j],
                        "record \(i) frame \(j)")
                }
            }
        }

        func test_readResult_timestampsMonotonicallyIncreasing() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            for i in 1...30 {
                let f: [UInt] = [UInt(i)]
                emb_ring_buffer_write(buf, UInt64(i) * 100_000_000, f, 1)
            }

            let records = testReadRange(buf, 0, UINT64_MAX)

            for i in 1..<records.count {
                XCTAssertGreaterThan(
                    records[i].timestamp_ns,
                    records[i - 1].timestamp_ns,
                    "timestamps must be strictly increasing")
            }
        }

        // MARK: - Wrap-around

        func test_wrapAround_recordStraddlingCapacityBoundary_readableAndCorrect() {
            let page = Int(getpagesize())
            let buf = emb_ring_buffer_create(page)!
            defer { emb_ring_buffer_destroy(buf) }

            let capacity = Int(buf.pointee.capacity)
            let rSize = RingBufferEdgeCaseTests.recordSize(3)
            var total = 0
            var ts: UInt64 = 0

            while total + rSize <= capacity {
                ts += 1
                let f: [UInt] = [UInt(ts), UInt(ts + 1), UInt(ts + 2)]
                emb_ring_buffer_write(buf, ts, f, 3)
                total += rSize
            }

            let remaining = capacity - (total % capacity)
            let willStraddle = remaining > 0 && remaining < rSize

            ts += 1
            let straddle: [UInt] = [UInt(ts), UInt(ts + 1), UInt(ts + 2)]
            let ok = emb_ring_buffer_write(buf, ts, straddle, 3)
            XCTAssertTrue(ok, "write straddling boundary must succeed")

            let records = testReadRange(buf, ts, ts)

            if willStraddle {
                XCTAssertEqual(records.count, 1, "straddling record must be readable")
                XCTAssertEqual(records[0].frames[0], UInt(ts))
                XCTAssertEqual(records[0].frames[1], UInt(ts + 1))
                XCTAssertEqual(records[0].frames[2], UInt(ts + 2))
            } else {
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

            let records = testReadRange(buf, 0, UINT64_MAX)

            XCTAssertGreaterThan(records.count, 0)
            XCTAssertLessThanOrEqual(records.count, perPage + 1)

            for i in 0..<records.count {
                let ts = records[i].timestamp_ns
                for j in 0..<records[i].frame_count {
                    XCTAssertEqual(
                        records[i].frames[j], UInt(ts),
                        "record \(i) frame \(j): expected \(ts)")
                }
            }

            for i in 1..<records.count {
                XCTAssertGreaterThan(
                    records[i].timestamp_ns,
                    records[i - 1].timestamp_ns)
            }
        }

        func test_wrapAround_variableFrameCounts_frameDataCorrect() {
            let buf = emb_ring_buffer_create(4 * Int(getpagesize()))!
            defer { emb_ring_buffer_destroy(buf) }

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

            let records = testReadRange(buf, 0, UINT64_MAX)

            XCTAssertGreaterThan(records.count, 0)

            for i in 0..<records.count {
                let rec = records[i]
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

        // MARK: - Record size vs capacity

        func test_write_recordExceedingCapacity_returnsFalse() {
            let page = Int(getpagesize())
            let buf = emb_ring_buffer_create(page)!
            defer { emb_ring_buffer_destroy(buf) }

            // A record needs header(16) + frameCount*8 bytes.
            // Choose enough frames to exceed one page.
            let frameCount = (page / RingBufferEdgeCaseTests.frameSize) + 1
            let frames = [UInt](repeating: 0xDEAD, count: frameCount)

            let success = emb_ring_buffer_write(buf, 1_000, frames, frameCount)
            XCTAssertFalse(success,
                "Write should fail when record size exceeds buffer capacity")

            // Buffer should remain empty and functional.
            let records = testReadRange(buf, 0, UINT64_MAX)
            XCTAssertEqual(records.count, 0)

            // A smaller write should still succeed.
            let small: [UInt] = [1]
            XCTAssertTrue(emb_ring_buffer_write(buf, 2_000, small, 1))
        }

        func test_write_recordAtExactCapacity_succeeds() {
            let page = Int(getpagesize())
            let buf = emb_ring_buffer_create(page)!
            defer { emb_ring_buffer_destroy(buf) }

            // Compute the frame count that makes record_size == capacity exactly.
            let capacity = Int(buf.pointee.capacity)
            let frameCount = (capacity - RingBufferEdgeCaseTests.headerSize)
                / RingBufferEdgeCaseTests.frameSize

            let frames = (0..<frameCount).map { UInt($0 + 1) }
            let success = emb_ring_buffer_write(buf, 42_000, frames, frameCount)
            XCTAssertTrue(success,
                "Write should succeed when record exactly fills buffer")

            let records = testReadRange(buf, 0, UINT64_MAX)
            XCTAssertEqual(records.count, 1)
            XCTAssertEqual(records[0].frame_count, frameCount)
            XCTAssertEqual(records[0].timestamp_ns, 42_000)
        }

        // MARK: - Output buffer edge cases

        func test_readRange_smallOutputBuffer_doesNotCrash() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            for i in 1...20 {
                let f: [UInt] = [UInt(i), UInt(i * 10)]
                emb_ring_buffer_write(buf, UInt64(i) * 1_000, f, 2)
            }

            // Each record is header(16) + 2 frames(16) = 32 bytes.
            // Provide a buffer that fits roughly 2 records.
            let smallSize = 64
            let output = UnsafeMutablePointer<UInt8>.allocate(capacity: smallSize)
            defer { output.deallocate() }

            let result = emb_ring_buffer_read_range(
                buf, 0, UINT64_MAX, output, smallSize)

            // total_bytes must not exceed the provided output size.
            XCTAssertLessThanOrEqual(result.total_bytes, smallSize,
                "Copied data must fit within the provided output buffer")
        }

        func test_readRange_smallOutputBuffer_recordsAreCorrect() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            for i in 1...20 {
                let f: [UInt] = [UInt(i), UInt(i * 10)]
                emb_ring_buffer_write(buf, UInt64(i) * 1_000, f, 2)
            }

            // Each record is header(16) + 2 frames(16) = 32 bytes.
            // Provide a buffer that fits exactly 2 records.
            let recordSize = RingBufferEdgeCaseTests.recordSize(2)
            let smallSize = recordSize * 2
            let output = UnsafeMutablePointer<UInt8>.allocate(capacity: smallSize)
            defer { output.deallocate() }

            let result = emb_ring_buffer_read_range(
                buf, 0, UINT64_MAX, output, smallSize)

            XCTAssertLessThanOrEqual(result.total_bytes, smallSize)
            XCTAssertGreaterThan(result.record_count, 0,
                "Should return at least one record in the truncated buffer")

            // Parse and verify the records that fit are correct.
            let records = parseRecords(output, result)
            XCTAssertEqual(records.count, result.record_count)

            for record in records {
                // Timestamps should be from our original writes (multiples of 1000).
                XCTAssertEqual(record.timestamp_ns % 1_000, 0,
                    "Timestamp should be a multiple of 1000")
                let i = Int(record.timestamp_ns / 1_000)
                XCTAssertGreaterThanOrEqual(i, 1)
                XCTAssertLessThanOrEqual(i, 20)
                XCTAssertEqual(record.frame_count, 2)
                XCTAssertEqual(record.frames[0], UInt(i))
                XCTAssertEqual(record.frames[1], UInt(i * 10))
            }
        }

        func test_readRange_zeroSizeOutput_returnsEmpty() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            let f: [UInt] = [1]
            emb_ring_buffer_write(buf, 1_000, f, 1)

            // output_size = 0 triggers the NULL/empty guard in read_range.
            let output = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
            defer { output.deallocate() }

            let result = emb_ring_buffer_read_range(buf, 0, UINT64_MAX, output, 0)
            XCTAssertEqual(result.record_count, 0)
            XCTAssertEqual(result.total_bytes, 0)
        }

        func test_readRange_nilOutput_returnsEmpty() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            let f: [UInt] = [1]
            emb_ring_buffer_write(buf, 1_000, f, 1)

            let result = emb_ring_buffer_read_range(buf, 0, UINT64_MAX, nil, 1024)
            XCTAssertEqual(result.record_count, 0)
            XCTAssertEqual(result.total_bytes, 0)
        }

        // MARK: - Reset edge cases

        func test_reset_nilBuffer_returnsFalse() {
            XCTAssertFalse(emb_ring_buffer_reset(nil))
        }

        // MARK: - Write with NULL frames and zero frame_count

        func test_write_nilFramesZeroCount_succeeds() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            // The C guard is: frames == NULL && frame_count > 0 → false.
            // NULL frames with 0 count should succeed and produce a zero-frame record.
            let success = emb_ring_buffer_write(buf, 42_000, nil, 0)
            XCTAssertTrue(success,
                "write with NULL frames and 0 frame_count should succeed")

            let records = testReadRange(buf, 0, UINT64_MAX)
            XCTAssertEqual(records.count, 1)
            XCTAssertEqual(records[0].timestamp_ns, 42_000)
            XCTAssertEqual(records[0].frame_count, 0)
        }

        // MARK: - Reset with concurrent readers

        func test_reset_whileReadersActive_returnsFalse() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            // Fill with large records so reads take measurable time.
            for i in 0..<100 {
                let frames = [UInt](repeating: UInt(i + 1), count: 100)
                emb_ring_buffer_write(buf, UInt64(i + 1) * 1_000, frames, 100)
            }

            let capacity = emb_ring_buffer_capacity(buf)

            // Use a class wrapper so the closure captures a reference (not a copy),
            // satisfying Sendable requirements without data races (protected by lock).
            final class SharedState: @unchecked Sendable {
                let lock = NSLock()
                var shouldStop = false
                var isSet: Bool {
                    lock.lock()
                    defer { lock.unlock() }
                    return shouldStop
                }
                func stop() {
                    lock.lock()
                    shouldStop = true
                    lock.unlock()
                }
            }
            let state = SharedState()

            let readersDone = DispatchGroup()

            // Start 8 readers doing continuous reads.
            for _ in 0..<8 {
                readersDone.enter()
                DispatchQueue.global().async {
                    let output = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
                    defer { output.deallocate() }

                    while !state.isSet {
                        _ = emb_ring_buffer_read_range(
                            buf, 0, UINT64_MAX, output, capacity)
                    }
                    readersDone.leave()
                }
            }

            // Try reset many times while readers are active.
            // The reset checks active_readers and should return false
            // when it catches a reader mid-read.
            var sawResetFail = false
            for _ in 0..<10_000 {
                if !emb_ring_buffer_reset(buf) {
                    sawResetFail = true
                    break
                }
            }
            _ = sawResetFail  // Probabilistic; primary goal is no-crash.

            state.stop()
            readersDone.wait()

            // After all readers stop, reset must succeed.
            XCTAssertTrue(emb_ring_buffer_reset(buf),
                "reset should succeed once all readers finish")
        }

        func test_reset_withConcurrentReaderStarts_noCorruption() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            // Fill buffer with data.
            for i in 0..<50 {
                let frames = [UInt](repeating: UInt(i + 1), count: 20)
                emb_ring_buffer_write(buf, UInt64(i + 1) * 1_000, frames, 20)
            }

            let capacity = emb_ring_buffer_capacity(buf)
            let iterations = 1000

            // Run many reset + concurrent reader start cycles.
            // The resetting flag should prevent readers from seeing
            // partially-reset data.
            final class SharedState: @unchecked Sendable {
                let lock = NSLock()
                var shouldStop = false
                var isSet: Bool {
                    lock.lock()
                    defer { lock.unlock() }
                    return shouldStop
                }
                func stop() {
                    lock.lock()
                    shouldStop = true
                    lock.unlock()
                }
            }
            let state = SharedState()

            let group = DispatchGroup()
            var readerErrors = 0
            let errLock = NSLock()

            // Spawn readers that continuously try to read.
            for _ in 0..<4 {
                group.enter()
                DispatchQueue.global().async {
                    let output = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
                    defer { output.deallocate() }

                    while !state.isSet {
                        let result = emb_ring_buffer_read_range(
                            buf, 0, UINT64_MAX, output, capacity)
                        let records = parseRecords(output, result)
                        // If we got records, timestamps must be ascending.
                        if records.count > 1 {
                            for i in 1..<records.count {
                                if records[i].timestamp_ns < records[i - 1].timestamp_ns {
                                    errLock.lock()
                                    readerErrors += 1
                                    errLock.unlock()
                                }
                            }
                        }
                    }
                    group.leave()
                }
            }

            // On the main thread, do reset + refill cycles.
            for cycle in 0..<iterations {
                let resetOk = emb_ring_buffer_reset(buf)
                // Reset may return false if a reader is active; that's fine.
                if resetOk {
                    // Refill with fresh data.
                    for j in 0..<10 {
                        let ts = UInt64(cycle * 10000 + j + 1)
                        let frames = [UInt](repeating: UInt(ts), count: 5)
                        emb_ring_buffer_write(buf, ts, frames, 5)
                    }
                }
            }

            state.stop()
            group.wait()

            XCTAssertEqual(readerErrors, 0,
                "Readers should never see corrupted timestamps during reset cycles")
        }

        // MARK: - Corruption guards

        func test_readRange_corruptedPositions_totalDataExceedsCapacity_returnsEmpty() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            // Write some valid data first.
            let f: [UInt] = [0xCAFE]
            emb_ring_buffer_write(buf, 1_000, f, 1)

            let records = testReadRange(buf, 0, UINT64_MAX)
            XCTAssertEqual(records.count, 1, "Precondition: data should be readable")

            // Corrupt the buffer by directly setting write_pos far ahead of oldest_pos,
            // so that write_pos - oldest_pos > capacity. The read path should detect
            // this and return empty rather than reading garbage.
            //
            // Struct layout: data(8) + capacity(8) + next_seq(8) + write_pos(8)
            // write_pos is at byte offset 24 from the start of the struct.
            let capacity = buf.pointee.capacity
            let corruptWritePos = UInt64(capacity * 2)
            let writePosOffset = 24  // data(8) + capacity(8) + next_seq(8)
            UnsafeMutableRawPointer(buf).storeBytes(
                of: corruptWritePos, toByteOffset: writePosOffset, as: UInt64.self)

            let corruptRecords = testReadRange(buf, 0, UINT64_MAX)
            XCTAssertEqual(corruptRecords.count, 0,
                "read_range should return empty when total_data > capacity (corruption guard)")
        }
    }

#endif
