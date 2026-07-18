//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS)

    import EmbraceProfilingSampler
    import Foundation
    import XCTest

    @testable import EmbraceProfiling

    /// Integration tests for the file-backed engine path + recovery (Step 6).
    final class ProfilingEngineFileBackedTests: XCTestCase {
        private var dir: URL!

        override func setUp() {
            super.setUp()
            ProfilingEngine.shared.resetForTesting()
            dir = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("embprof-engine-\(UUID().uuidString)", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        override func tearDown() {
            ProfilingEngine.shared.resetForTesting()
            if let dir { try? FileManager.default.removeItem(at: dir) }
            super.tearDown()
        }

        /// Build a "crashed previous session" file directly via the C store API: records written, then
        /// destroyed WITHOUT finalize, so format_version stays 1 (exactly what a crash leaves behind).
        private func makeCrashedSessionFile(named name: String, frames: [UInt], ts: UInt64) {
            let path = dir.appendingPathComponent(name).path
            var err: Int32 = 0
            guard let store = emb_profile_store_create(path, 256 * 1024, nil, &err) else {
                return XCTFail("store create failed, errno=\(err)")
            }
            let buf = emb_profile_store_buffer(store)
            frames.withUnsafeBufferPointer { fb in
                _ = emb_ring_buffer_write(buf, ts, fb.baseAddress, fb.count, 1 /* running */, 0)
            }
            emb_profile_store_destroy(store)
        }

        func test_recoverableSessions_listsCrashedSession_thenRecover() {
            makeCrashedSessionFile(named: "aabb.embprof", frames: [0x11, 0x22], ts: 100)

            let sessions = ProfilingEngine.shared.recoverableSessions(in: dir)
            XCTAssertEqual(sessions.count, 1)
            let handle = try! XCTUnwrap(sessions.first)
            XCTAssertEqual(handle.sessionId, "aabb")
            XCTAssertEqual(handle.status, .recoverable)
            XCTAssertGreaterThan(handle.byteSize, 0)

            let recovery = ProfilingEngine.shared.recover(handle)
            guard case let .recovered(result) = recovery else {
                return XCTFail("expected .recovered, got \(recovery)")
            }
            XCTAssertEqual(result.samples.count, 1)
            XCTAssertEqual(result.samples[0].threadState, .running)
            XCTAssertEqual(Array(result.frames), [0x11, 0x22])
        }

        /// End-to-end: a real I/O failure (permission denied) at recovery time must surface its `errno`
        /// in the `.unreadable` reason string, not just a flat "I/O error".
        func test_recover_permissionDenied_reasonIncludesErrno() throws {
            try XCTSkipIf(getuid() == 0, "root bypasses file permission checks")
            makeCrashedSessionFile(named: "noperm.embprof", frames: [0x11], ts: 100)
            let handle = try XCTUnwrap(ProfilingEngine.shared.recoverableSessions(in: dir).first)

            try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: handle.url.path)
            defer { try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: handle.url.path) }

            guard case let .unreadable(reason) = ProfilingEngine.shared.recover(handle) else {
                return XCTFail("expected .unreadable for a permission-denied file")
            }
            XCTAssertTrue(reason.contains("errno"), "reason should include the errno: \(reason)")
        }

        func test_recoverableSessions_skipsFinalizedForRecovery() {
            // A finalized (cleanly-stopped) file: listed with .finalized status, recover → .finalized.
            let path = dir.appendingPathComponent("ccdd.embprof").path
            var err: Int32 = 0
            let store = try! XCTUnwrap(emb_profile_store_create(path, 256 * 1024, nil, &err))
            [0x11 as UInt].withUnsafeBufferPointer {
                _ = emb_ring_buffer_write(emb_profile_store_buffer(store), 100, $0.baseAddress, 1, 1, 0)
            }
            emb_profile_store_finalize(store)  // version-0 tombstone
            emb_profile_store_destroy(store)

            let handle = try! XCTUnwrap(ProfilingEngine.shared.recoverableSessions(in: dir).first)
            XCTAssertEqual(handle.status, .finalized)
            guard case .finalized = ProfilingEngine.shared.recover(handle) else {
                return XCTFail("finalized file should recover as .finalized")
            }
        }

        func test_recoverableSessions_missingDirectory_returnsEmpty() {
            let missing = dir.appendingPathComponent("does-not-exist", isDirectory: true)
            XCTAssertTrue(ProfilingEngine.shared.recoverableSessions(in: missing).isEmpty)
        }

        func test_recoverableSessions_emptyDirectory_returnsEmpty() {
            XCTAssertTrue(ProfilingEngine.shared.recoverableSessions(in: dir).isEmpty)
        }

        func test_delete_removesSessionFile() {
            makeCrashedSessionFile(named: "dead.embprof", frames: [0x1], ts: 1)
            let handle = try! XCTUnwrap(ProfilingEngine.shared.recoverableSessions(in: dir).first)

            XCTAssertTrue(ProfilingEngine.shared.delete(handle))
            XCTAssertFalse(FileManager.default.fileExists(atPath: handle.url.path))
            XCTAssertTrue(ProfilingEngine.shared.recoverableSessions(in: dir).isEmpty)
        }

        func test_fileBackedStart_writeRetrieve_andFinalize() {
            let engine = ProfilingEngine.shared
            let sid = [UInt8](repeating: 0xCD, count: 16)

            let r = engine.start(configuration: ProfilingConfiguration(startPaused: true),
                                 directory: dir, sessionId: sid)
            XCTAssertEqual(r, .started)

            // startPaused → the worker isn't writing, so a direct test write is race-free.
            XCTAssertTrue(engine.writeSampleForTesting(timestamp: 100, frames: [0xAA], threadState: 3 /* waiting */))

            guard case let .success(pr) = engine.retrieveSamples(from: 0, through: .max) else {
                return XCTFail("retrieve failed")
            }
            XCTAssertEqual(pr.samples.count, 1)
            XCTAssertEqual(pr.samples[0].threadState, .waiting)
            XCTAssertEqual(Array(pr.frames), [0xAA])

            // The session's file exists under the injected directory.
            let fileName = sid.map { String(format: "%02x", $0) }.joined() + ".embprof"
            XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent(fileName).path))

            engine.stop()
            let deadline = Date().addingTimeInterval(2)
            while engine.isActive && Date() < deadline { usleep(1000) }
            engine.finalizeStorage()  // clean stop → version-0 tombstone
        }

        /// finalizeStorage() must refuse to tombstone while the worker is still active — otherwise the
        /// version-0 marker would make recovery discard the whole (not-yet-drained) file. We start a
        /// file-backed (paused, so still active) session with a sample, call finalizeStorage() while
        /// active, then tear down without finalizing and confirm the session is STILL recoverable —
        /// proving the call was a no-op. (Without the guard, recovery would return FINALIZED instead.)
        func test_finalizeStorage_whileActive_isNoOp_sessionStaysRecoverable() {
            let engine = ProfilingEngine.shared
            let sid = [UInt8](repeating: 0x5A, count: 16)

            XCTAssertEqual(engine.start(configuration: ProfilingConfiguration(startPaused: true),
                                        directory: dir, sessionId: sid), .started)
            XCTAssertTrue(engine.writeSampleForTesting(timestamp: 100, frames: [0xAA], threadState: 1))
            XCTAssertTrue(engine.isActive)

            engine.finalizeStorage()  // active → must be a no-op (leave the session recoverable)

            engine.stop()
            let deadline = Date().addingTimeInterval(2)
            while engine.isActive && Date() < deadline { usleep(1000) }
            engine.resetForTesting()  // tears down the store (file persists, NOT finalized), clears active name

            // Still recoverable (version 1) → finalize while active was a no-op. Were it not, the file
            // would be tombstoned (.finalized) and recover would return nothing.
            let handle = try! XCTUnwrap(engine.recoverableSessions(in: dir).first)
            XCTAssertEqual(handle.status, .recoverable)
            guard case let .recovered(result) = engine.recover(handle) else {
                return XCTFail("session should still be recoverable; finalize while active must be a no-op")
            }
            XCTAssertEqual(result.samples.count, 1)
        }
    }

#endif
