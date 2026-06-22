//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS)

    import EmbraceProfilingSampler
    import Foundation
    import XCTest

    /// Tests for the file-backed store (Step 3: create + footer + mapping).
    final class ProfileStoreTests: XCTestCase {

        private func tempPath() -> String {
            (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("embprof-\(UUID().uuidString).embprof")
        }

        func test_create_writeRead_roundTripsThroughFileBackedBuffer() {
            let path = tempPath()
            defer { try? FileManager.default.removeItem(atPath: path) }

            let sid = [UInt8](repeating: 0xAB, count: 16)
            var err: Int32 = 0
            guard let store = emb_profile_store_create(path, 256 * 1024, sid, &err) else {
                return XCTFail("store create failed, errno=\(err)")
            }
            defer { emb_profile_store_destroy(store) }

            guard let buf = emb_profile_store_buffer(store) else { return XCTFail("no buffer") }

            let frames: [UInt] = [0x1111, 0x2222, 0x3333]
            XCTAssertEqual(ringWrite(buf, 1_000, frames, frames.count, 1 /* running */, 0), EMB_RING_WRITE_OK)
            XCTAssertEqual(ringWrite(buf, 2_000, frames, frames.count, 3 /* waiting */, 0), EMB_RING_WRITE_OK)

            let records = testReadRange(buf, 0, UINT64_MAX)
            XCTAssertEqual(records.count, 2)
            XCTAssertEqual(records[0].frames, frames)
            XCTAssertEqual(records[0].thread_state, 1)
            XCTAssertEqual(records[1].thread_state, 3)
        }

        func test_create_writesValidFrozenIdentityToDisk() throws {
            let path = tempPath()
            defer { try? FileManager.default.removeItem(atPath: path) }

            var err: Int32 = 0
            guard let store = emb_profile_store_create(path, 256 * 1024, nil, &err) else {
                return XCTFail("create failed, errno=\(err)")
            }
            // Write a record, then tear down — munmap flushes the dirty pages to the file.
            ringWrite(emb_profile_store_buffer(store), 1_000, [0xDEAD], 1, 1, 0)
            emb_profile_store_destroy(store)

            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            XCTAssertGreaterThan(data.count, MemoryLayout<emb_profile_ident_t>.size)

            // Frozen identity is the last 16 bytes. Copy into an aligned struct (avoids
            // unaligned-load issues on the Data slice).
            var ident = emb_profile_ident_t()
            _ = withUnsafeMutableBytes(of: &ident) { data.suffix(16).copyBytes(to: $0) }
            XCTAssertEqual(ident.magic, EMB_PROFILE_FILE_MAGIC)
            XCTAssertEqual(ident.format_version, UInt64(EMB_PROFILE_FORMAT_VER))
        }

        func test_destroy_doesNotDeleteFile() {
            let path = tempPath()
            defer { try? FileManager.default.removeItem(atPath: path) }

            var err: Int32 = 0
            let store = emb_profile_store_create(path, 256 * 1024, nil, &err)
            XCTAssertNotNil(store, "create failed, errno=\(err)")
            emb_profile_store_destroy(store)

            // We never delete — Embrace owns deletion/retention.
            XCTAssertTrue(FileManager.default.fileExists(atPath: path),
                          "store must not delete the file on destroy")
        }

        func test_create_badArgs_returnsNilWithErrno() {
            var err: Int32 = 0
            XCTAssertNil(emb_profile_store_create(nil, 256 * 1024, nil, &err))
            XCTAssertEqual(err, EINVAL)
        }

        // MARK: - Step 4: reset + finalize

        func test_reset_reusesFile_clearsRecords_thenUsable() {
            let path = tempPath()
            defer { try? FileManager.default.removeItem(atPath: path) }

            var err: Int32 = 0
            guard let store = emb_profile_store_create(path, 256 * 1024, nil, &err) else {
                return XCTFail("create failed, errno=\(err)")
            }
            defer { emb_profile_store_destroy(store) }
            let buf = emb_profile_store_buffer(store)!

            ringWrite(buf, 1_000, [0xAA], 1, 1, 0)
            XCTAssertEqual(testReadRange(buf, 0, UINT64_MAX).count, 1)

            XCTAssertTrue(emb_profile_store_reset(store))
            XCTAssertEqual(testReadRange(buf, 0, UINT64_MAX).count, 0, "reset clears records")

            // Still usable after reset (same file reused).
            ringWrite(buf, 2_000, [0xBB], 1, 1, 0)
            let records = testReadRange(buf, 0, UINT64_MAX)
            XCTAssertEqual(records.count, 1)
            XCTAssertEqual(records[0].frames, [0xBB])
        }

        func test_finalize_writesVersionZeroTombstoneToDisk() throws {
            let path = tempPath()
            defer { try? FileManager.default.removeItem(atPath: path) }

            var err: Int32 = 0
            guard let store = emb_profile_store_create(path, 256 * 1024, nil, &err) else {
                return XCTFail("create failed, errno=\(err)")
            }
            ringWrite(emb_profile_store_buffer(store), 1_000, [0xCC], 1, 1, 0)
            emb_profile_store_finalize(store)
            emb_profile_store_destroy(store)

            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            var ident = emb_profile_ident_t()
            _ = withUnsafeMutableBytes(of: &ident) { data.suffix(16).copyBytes(to: $0) }
            XCTAssertEqual(ident.magic, EMB_PROFILE_FILE_MAGIC, "magic stays intact")
            XCTAssertEqual(ident.format_version, 0, "finalize writes the version-0 tombstone")
        }
    }

#endif
