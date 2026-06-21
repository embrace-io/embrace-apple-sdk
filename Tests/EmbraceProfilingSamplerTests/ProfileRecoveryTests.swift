//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS)

    import EmbraceProfilingSampler
    import Foundation
    import XCTest

    /// Accumulates records delivered by `emb_profile_recover`'s callback.
    final class RecoverSink {
        struct Rec { let ts: UInt64; let state: UInt8; let flags: UInt8; let frames: [UInt] }
        var records: [Rec] = []
    }

    // Non-capturing → convertible to the C function pointer `emb_profile_record_cb`.
    private let recoverCallback: emb_profile_record_cb = { ctx, ts, state, flags, framesPtr, count in
        let sink = Unmanaged<RecoverSink>.fromOpaque(ctx!).takeUnretainedValue()
        let frames = (framesPtr != nil && count > 0)
            ? Array(UnsafeBufferPointer(start: framesPtr, count: Int(count)))
            : []
        sink.records.append(.init(ts: ts, state: state, flags: flags, frames: frames))
    }

    /// Tests for the read-only recovery scanner (Step 5).
    final class ProfileRecoveryTests: XCTestCase {

        private func tempPath() -> String {
            (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("embprof-rec-\(UUID().uuidString).embprof")
        }

        private func recoverAll(_ path: String) -> (emb_profile_recover_status_t, [RecoverSink.Rec]) {
            let sink = RecoverSink()
            let status = emb_profile_recover(path, recoverCallback, Unmanaged.passUnretained(sink).toOpaque())
            return (status, sink.records)
        }

        /// A store created + written + destroyed (but NOT finalized) is exactly a "crashed session"
        /// file: valid version + records on disk. Recovery should return them in order.
        func test_recover_crashedSession_emitsRecordsInOrder() {
            let path = tempPath()
            defer { try? FileManager.default.removeItem(atPath: path) }

            var err: Int32 = 0
            guard let store = emb_profile_store_create(path, 256 * 1024, nil, &err) else {
                return XCTFail("create failed, errno=\(err)")
            }
            let buf = emb_profile_store_buffer(store)
            XCTAssertEqual(ringWrite(buf, 100, [0x11, 0x12], 2, 1 /* running */, 0), EMB_RING_WRITE_OK)
            XCTAssertEqual(ringWrite(buf, 200, [0x21], 1, 3 /* waiting */, 0), EMB_RING_WRITE_OK)
            XCTAssertEqual(ringWrite(buf, 300, [0x31, 0x32, 0x33], 3, 1, 0), EMB_RING_WRITE_OK)
            emb_profile_store_destroy(store)  // simulate process death (version stays 1)

            let (status, recs) = recoverAll(path)
            XCTAssertEqual(status, EMB_PROFILE_RECOVER_OK)
            XCTAssertEqual(recs.count, 3)
            XCTAssertEqual(recs.map { $0.ts }, [100, 200, 300])
            XCTAssertEqual(recs.map { $0.state }, [1, 3, 1])
            XCTAssertEqual(recs[0].frames, [0x11, 0x12])
            XCTAssertEqual(recs[1].frames, [0x21])
            XCTAssertEqual(recs[2].frames, [0x31, 0x32, 0x33])
        }

        func test_recover_finalizedSession_returnsFinalized() {
            let path = tempPath()
            defer { try? FileManager.default.removeItem(atPath: path) }

            var err: Int32 = 0
            guard let store = emb_profile_store_create(path, 256 * 1024, nil, &err) else { return XCTFail() }
            ringWrite(emb_profile_store_buffer(store), 100, [0x11], 1, 1, 0)
            emb_profile_store_finalize(store)   // clean stop → version 0
            emb_profile_store_destroy(store)

            let (status, recs) = recoverAll(path)
            XCTAssertEqual(status, EMB_PROFILE_RECOVER_FINALIZED)
            XCTAssertEqual(recs.count, 0)
        }

        func test_recover_emptyBuffer_returnsOKWithNoRecords() {
            let path = tempPath()
            defer { try? FileManager.default.removeItem(atPath: path) }

            var err: Int32 = 0
            guard let store = emb_profile_store_create(path, 256 * 1024, nil, &err) else { return XCTFail() }
            emb_profile_store_destroy(store)  // never wrote anything

            let (status, recs) = recoverAll(path)
            XCTAssertEqual(status, EMB_PROFILE_RECOVER_OK)
            XCTAssertEqual(recs.count, 0)
        }

        func test_recover_notOurFile_returnsNotOurs() throws {
            let path = tempPath()
            defer { try? FileManager.default.removeItem(atPath: path) }
            // A file big enough to pass the size check, but with no valid magic at EOF.
            try Data(count: 64 * 1024).write(to: URL(fileURLWithPath: path))

            let (status, recs) = recoverAll(path)
            XCTAssertEqual(status, EMB_PROFILE_RECOVER_NOT_OURS)
            XCTAssertEqual(recs.count, 0)
        }

        func test_recover_missingFile_returnsIOError() {
            let (status, _) = recoverAll(tempPath() + "-nope")
            XCTAssertEqual(status, EMB_PROFILE_RECOVER_IO_ERROR)
        }

        // MARK: - Step 7: adversarial hardening

        /// Recovery must read writer dirty pages that were NEVER explicitly flushed (no msync, no
        /// munmap) — exactly the state a SIGKILL leaves behind. Proven in-process: write into the
        /// MAP_SHARED mapping, then recover from a FRESH fd + mapping of the same file WITHOUT
        /// destroying the store first. MAP_SHARED pages are coherent through the unified buffer cache,
        /// so the fresh mapping observes the un-flushed writes. (`killtest.c` separately proves the
        /// kernel flushes these same pages to the vnode on a real cross-process SIGKILL; `fork()` is
        /// unavailable in Swift, so that half lives in the C harness.)
        func test_recover_readsUnflushedSharedWrites() {
            let path = tempPath()
            defer { try? FileManager.default.removeItem(atPath: path) }

            var err: Int32 = 0
            guard let store = emb_profile_store_create(path, 256 * 1024, nil, &err) else {
                return XCTFail("create failed, errno=\(err)")
            }
            defer { emb_profile_store_destroy(store) }
            let buf = emb_profile_store_buffer(store)
            _ = ringWrite(buf, 100, [0xAB], 1, 1, 0)
            _ = ringWrite(buf, 200, [0xCD], 1, 3, 0)
            _ = ringWrite(buf, 300, [0xEF], 1, 1, 0)
            // NO destroy / flush / finalize here — recover the still-live file from a fresh mapping.

            let (status, recs) = recoverAll(path)
            XCTAssertEqual(status, EMB_PROFILE_RECOVER_OK)
            XCTAssertEqual(recs.count, 3)
            XCTAssertEqual(recs.map { $0.ts }, [100, 200, 300])
            XCTAssertEqual(recs.map { $0.state }, [1, 3, 1])
        }

        // --- deterministic on-disk corruption (two 1-frame records: rec0 @0, rec1 @24) ---

        /// Writes two 1-frame records and tears down (flush), leaving a valid "crashed" file on disk.
        private func makeTwoRecordFile(_ path: String) {
            var err: Int32 = 0
            guard let store = emb_profile_store_create(path, 256 * 1024, nil, &err) else {
                return XCTFail("create failed, errno=\(err)")
            }
            let buf = emb_profile_store_buffer(store)
            let f: [UInt] = [0xAB]
            _ = ringWrite(buf, 100, f, 1, 1, 0)   // rec0 @ byte 0  (seq 0)
            _ = ringWrite(buf, 200, f, 1, 3, 0)   // rec1 @ byte 24 (seq 2)
            emb_profile_store_destroy(store)       // flush; format_version stays 1
        }

        private func patch(_ path: String, _ offset: Int, _ bytes: [UInt8]) {
            guard let fh = FileHandle(forUpdatingAtPath: path) else { return XCTFail("open for update") }
            try? fh.seek(toOffset: UInt64(offset))
            fh.write(Data(bytes))
            try? fh.close()
        }

        private func leBytes<T: FixedWidthInteger>(_ v: T) -> [UInt8] {
            withUnsafeBytes(of: v.littleEndian) { Array($0) }
        }

        func test_recover_tornTail_stopsAtOddSeq() {
            let path = tempPath(); defer { try? FileManager.default.removeItem(atPath: path) }
            makeTwoRecordFile(path)
            patch(path, 24, leBytes(UInt32(3)))  // rec1 seq → odd → torn
            let (status, recs) = recoverAll(path)
            XCTAssertEqual(status, EMB_PROFILE_RECOVER_OK)
            XCTAssertEqual(recs.count, 1, "walk stops at the torn second record")
            XCTAssertEqual(recs.first?.ts, 100)
        }

        func test_recover_zeroedPage_stopsAtZeroFrameCount() {
            let path = tempPath(); defer { try? FileManager.default.removeItem(atPath: path) }
            makeTwoRecordFile(path)
            patch(path, 28, leBytes(UInt16(0)))  // rec1 frame_count (offset 24+4) → 0 (zeroed-page sentinel)
            let (status, recs) = recoverAll(path)
            XCTAssertEqual(status, EMB_PROFILE_RECOVER_OK)
            XCTAssertEqual(recs.count, 1, "walk stops at the zeroed second record")
            XCTAssertEqual(recs.first?.ts, 100)
        }

        func test_recover_corruptControlBlock_returnsCorrupt() {
            let path = tempPath(); defer { try? FileManager.default.removeItem(atPath: path) }
            makeTwoRecordFile(path)
            let dataCapacity = 256 * 1024  // page-aligned for 4K/16K
            patch(path, dataCapacity, leBytes(UInt64(dataCapacity * 4)))  // write_pos − oldest_pos > capacity
            let (status, recs) = recoverAll(path)
            XCTAssertEqual(status, EMB_PROFILE_RECOVER_CORRUPT)
            XCTAssertEqual(recs.count, 0)
        }

        func test_recover_wrongPageSize_returnsCorrupt() {
            let path = tempPath(); defer { try? FileManager.default.removeItem(atPath: path) }
            makeTwoRecordFile(path)
            let page = Int(getpagesize())
            let fileSize = 256 * 1024 + 2 * page
            let trailerSize = MemoryLayout<emb_profile_trailer_v1_t>.size
            let identSize = MemoryLayout<emb_profile_ident_t>.size
            // page_size field sits after footer_offset(8) + data_capacity(8) in the trailer.
            let pageSizeOffset = fileSize - identSize - trailerSize + 16
            patch(path, pageSizeOffset, leBytes(UInt32(0xDEAD)))
            let (status, _) = recoverAll(path)
            XCTAssertEqual(status, EMB_PROFILE_RECOVER_CORRUPT)
        }

        /// Regression for the record-walk overflow: write_pos/oldest_pos are absolute monotonic byte
        /// counters, and a crafted file can place write_pos within one record of UInt64.max. The OLD
        /// overrun guard `pos + rsize > write_pos` overflowed and wrongly ACCEPTED an over-long record
        /// (OOB read past the mapping on 4K-page builds; a garbage record on 16K). The fixed guard
        /// (`rsize > write_pos - pos`) must REJECT it. We assert via emitted-record count, which
        /// distinguishes old (≥1 garbage record) from new (0) even on this 16K-page host where the OOB
        /// itself doesn't reproduce.
        func test_recover_overflowGuard_rejectsRecordOverrunningNearUInt64Max() {
            let path = tempPath(); defer { try? FileManager.default.removeItem(atPath: path) }
            makeTwoRecordFile(path)  // gives a valid magic/trailer; we override the control block below

            let dataCapacity = 256 * 1024
            let writePos = UInt64.max - 84       // near the top of the u64 range
            let oldestPos = writePos - 16        // diff == one header → passes (write-oldest) <= capacity
            patch(path, dataCapacity, leBytes(writePos))           // control block: write_pos@0
            patch(path, dataCapacity + 8, leBytes(oldestPos))      //                oldest_pos@8

            // Plant a committed-looking header at oldest_pos's data offset, claiming the max frame count
            // so its record would overrun the 16-byte window.
            let recOffset = Int(oldestPos % UInt64(dataCapacity))
            patch(path, recOffset, leBytes(UInt32(0)))             // seq = 0 (even → committed)
            patch(path, recOffset + 4, leBytes(UInt16(1024)))      // frame_count = EMB_MAX_STACK_FRAMES

            let (status, recs) = recoverAll(path)
            XCTAssertEqual(status, EMB_PROFILE_RECOVER_OK)
            XCTAssertEqual(recs.count, 0, "an overrunning record near UInt64.max must be rejected, not accepted")
        }
    }

#endif
