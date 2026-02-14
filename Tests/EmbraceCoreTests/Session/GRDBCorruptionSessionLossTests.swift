//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import GRDB
@testable import EmbraceCore
import EmbraceStorageInternal
import EmbraceCommonInternal
import EmbraceSemantics
import TestSupport
import OpenTelemetrySdk

// MARK: - Reproduction tests for GRDB auto-recovery causing complete data loss
//
// Root cause chain:
//
// 1. GRDB storage encounters corruption (triggered/exacerbated by frequent OTA updates)
// 2. addResource() throws → visible as "Error setting JavaScript bundle path"
// 3. getDBQueueIfPossible() auto-recovery **deletes the entire DB** and creates a fresh one
// 4. SDK continues with stale in-memory session IDs that have no matching SessionRecord
// 5. fetchResourcesForSessionId(X) guard clause returns [] when session missing
// 6. ResourcePayload(from: []) produces all-null fields (app_version, os_name, etc.)
// 7. Both session AND log payloads sent with null resources → backend filter drops everything

class GRDBCorruptionSessionLossTests: XCTestCase {

    var storage: EmbraceStorage!
    var dbFileURL: URL!

    let testSessionId = SessionIdentifier(string: "AAEDB6CE-90C2-456B-97CB-91E0F5941CCA")!
    let testProcessId = ProcessIdentifier(hex: "AABB1234")!

    override func setUpWithError() throws {
        let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("GRDBCorruptionTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

        let fileName = "\(UUID().uuidString).sqlite"
        storage = try EmbraceStorage(
            options: .init(baseUrl: tmpDir, fileName: fileName),
            logger: MockLogger()
        )
        try storage.performMigration()

        dbFileURL = tmpDir.appendingPathComponent(fileName)
    }

    override func tearDownWithError() throws {
        if let storage = storage {
            try? storage.teardown()
        }
        if let url = dbFileURL {
            let dir = url.deletingLastPathComponent()
            try? FileManager.default.removeItem(at: dir)
        }
    }

    // MARK: - Helpers

    /// Adds a session, resources, and spans that mirror a healthy production state.
    @discardableResult
    private func populateHealthySession(
        in store: EmbraceStorage,
        sessionId: SessionIdentifier? = nil,
        processId: ProcessIdentifier? = nil
    ) throws -> SessionRecord {
        let sid = sessionId ?? testSessionId
        let pid = processId ?? testProcessId

        let session = try store.addSession(
            id: sid,
            state: .foreground,
            processId: pid,
            traceId: "trace-\(sid.toString)",
            spanId: "span-\(sid.toString)",
            startTime: Date(timeIntervalSinceNow: -60),
            endTime: Date()
        )

        // Resources with .process lifespan (matching how capture services store them)
        try store.addMetadata(
            key: AppResourceKey.appVersion.rawValue,
            value: "1.2.3",
            type: .requiredResource,
            lifespan: .process,
            lifespanId: pid.hex
        )
        try store.addMetadata(
            key: AppResourceKey.sdkVersion.rawValue,
            value: "0.0.1",
            type: .requiredResource,
            lifespan: .process,
            lifespanId: pid.hex
        )
        try store.addMetadata(
            key: ResourceAttributes.osName.rawValue,
            value: "iOS",
            type: .requiredResource,
            lifespan: .process,
            lifespanId: pid.hex
        )
        try store.addMetadata(
            key: ResourceAttributes.osType.rawValue,
            value: "darwin",
            type: .requiredResource,
            lifespan: .process,
            lifespanId: pid.hex
        )

        // Add a span associated with this session's process
        try store.addSpan(
            id: "span-id-\(UUID().uuidString)",
            name: "test-network-request",
            traceId: "trace-\(sid.toString)",
            type: SpanType(performance: "network"),
            data: Data(),
            startTime: Date(timeIntervalSinceNow: -30),
            endTime: Date(timeIntervalSinceNow: -10),
            processIdentifier: pid
        )

        return session
    }

    /// Simulates auto-recovery: closes DB, corrupts file, reopens (triggers getDBQueueIfPossible)
    private func simulateAutoRecovery() throws -> EmbraceStorage {
        try storage.teardown()

        // Overwrite the DB file with garbage bytes to trigger GRDB corruption detection
        try Data(repeating: 0xFF, count: 4096).write(to: dbFileURL)

        let baseDir = dbFileURL.deletingLastPathComponent()
        let fileName = dbFileURL.lastPathComponent

        let recovered = try EmbraceStorage(
            options: .init(baseUrl: baseDir, fileName: fileName),
            logger: MockLogger()
        )
        try recovered.performMigration()
        return recovered
    }

    // MARK: - Test 1: Baseline — healthy payloads have resources

    func test_baseline_healthyPayloadsHaveResources() throws {
        let session = try populateHealthySession(in: storage)

        let payload = SessionPayloadBuilder.build(for: session, storage: storage)

        XCTAssertNotNil(payload.resource.appVersion,
                        "Healthy payload must have app_version")
        XCTAssertNotNil(payload.resource.sdkVersion,
                        "Healthy payload must have sdk_version")
        XCTAssertNotNil(payload.resource.osName,
                        "Healthy payload must have os_name")

        // Verify spans are present
        let hasSpans = !payload.data.values.flatMap { $0 }.isEmpty
        XCTAssertTrue(hasSpans, "Healthy payload must contain spans")
    }

    // MARK: - Test 2: Missing session record → fetchResourcesForSessionId returns []

    func test_missingSessionRecord_fetchResourcesReturnsEmpty() throws {
        // Add resources with .process lifespan but do NOT add a matching SessionRecord
        try storage.addMetadata(
            key: AppResourceKey.appVersion.rawValue,
            value: "1.2.3",
            type: .requiredResource,
            lifespan: .process,
            lifespanId: testProcessId.hex
        )
        try storage.addMetadata(
            key: ResourceAttributes.osName.rawValue,
            value: "iOS",
            type: .requiredResource,
            lifespan: .process,
            lifespanId: testProcessId.hex
        )

        // The guard clause in fetchResourcesForSessionId returns [] when session is missing
        let nonExistentSessionId = SessionIdentifier(string: "BBEDB6CE-90C2-456B-97CB-91E0F5941CCA")!
        let resources = try storage.fetchResourcesForSessionId(nonExistentSessionId)

        XCTAssertTrue(resources.isEmpty,
                      "fetchResourcesForSessionId should return [] when session record is missing")

        // This is the core of the bug: empty resources → null payload fields
        let resourcePayload = ResourcePayload(from: resources)
        XCTAssertNil(resourcePayload.appVersion,
                     "ResourcePayload from empty array should have nil appVersion")
        XCTAssertNil(resourcePayload.osName,
                     "ResourcePayload from empty array should have nil osName")
    }

    // MARK: - Test 3: Auto-recovery wipes DB and loses all data

    func test_autoRecovery_wipesDBAndLosesAllData() throws {
        // Populate storage with session, resources, and spans
        try populateHealthySession(in: storage)

        // Verify data exists before corruption
        let sessionBefore = try storage.fetchSession(id: testSessionId)
        XCTAssertNotNil(sessionBefore, "Session should exist before corruption")

        let resourcesBefore = try storage.fetchResourcesForSessionId(testSessionId)
        XCTAssertFalse(resourcesBefore.isEmpty, "Resources should exist before corruption")

        // Simulate auto-recovery: corrupt and recreate
        let recovered = try simulateAutoRecovery()
        defer { try? recovered.teardown() }

        // The fresh DB should be healthy (tables exist) — verify by adding a dummy record
        let dummySession = try recovered.addSession(
            id: SessionIdentifier.random,
            state: .foreground,
            processId: ProcessIdentifier.current,
            traceId: "dummy-trace",
            spanId: "dummy-span",
            startTime: Date()
        )
        XCTAssertNotNil(dummySession, "Recovered storage should be healthy")

        // But ALL original data is gone
        let sessionAfter = try recovered.fetchSession(id: testSessionId)
        XCTAssertNil(sessionAfter,
                     "Original session should be gone after auto-recovery DB wipe")

        let resourcesAfter = try recovered.fetchResourcesForSessionId(testSessionId)
        XCTAssertTrue(resourcesAfter.isEmpty,
                      "All resources should be gone after auto-recovery DB wipe")

        let spansAfter = try recovered.fetchSpan(id: "span-id-test", traceId: "trace-\(testSessionId.toString)")
        XCTAssertNil(spansAfter,
                     "All spans should be gone after auto-recovery DB wipe")
    }

    // MARK: - Test 4: Stale session ID produces null resource payload (end-to-end)

    func test_autoRecovery_staleSessionId_producesNullResourcePayload() throws {
        // Set up healthy state and capture the session record (simulating SDK keeping it in memory)
        let staleSession = try populateHealthySession(in: storage)

        // Verify baseline: payload should have populated resources
        let baselinePayload = SessionPayloadBuilder.build(for: staleSession, storage: storage)
        XCTAssertNotNil(baselinePayload.resource.appVersion,
                        "Baseline payload must have app_version before corruption")

        // Simulate auto-recovery: DB gets wiped and recreated
        let recovered = try simulateAutoRecovery()
        defer { try? recovered.teardown() }

        // Build payload using the STALE session record (still in memory from before wipe)
        // This is exactly what happens in production: SessionController holds the SessionRecord
        // but the DB no longer has the matching row
        let corruptedPayload = SessionPayloadBuilder.build(for: staleSession, storage: recovered)

        // Payload is non-nil (fail-soft behavior)
        // But resource fields are all nil because fetchResourcesForSessionId returns []
        XCTAssertNil(corruptedPayload.resource.appVersion,
                     "Stale session → null app_version (backend defaultFilter drops this)")
        XCTAssertNil(corruptedPayload.resource.sdkVersion,
                     "Stale session → null sdk_version")
        XCTAssertNil(corruptedPayload.resource.osName,
                     "Stale session → null os_name (backend maps to PlatformUnknown)")

        // User spans should be gone (all wiped from DB).
        // Note: SessionPayloadBuilder synthesizes a session span from the in-memory SessionRecord,
        // so there will be exactly 1 span (the session span) but no user/performance spans.
        let allSpans = corruptedPayload.data["spans"] ?? []
        let nonSessionSpans = allSpans.filter { $0.name != "emb-session" }
        XCTAssertTrue(nonSessionSpans.isEmpty,
                      "User spans should be gone after DB wipe, only session span remains")

        // The payload still encodes to valid JSON (it gets uploaded, but backend drops it)
        let jsonData = try JSONEncoder().encode(corruptedPayload)
        XCTAssertFalse(jsonData.isEmpty,
                       "Corrupted payload should still encode to valid JSON")
    }

    // MARK: - Test 5: Log payload also has null resources

    func test_autoRecovery_logPayloadAlsoHasNullResources() throws {
        // Set up healthy state
        try populateHealthySession(in: storage)

        // Verify baseline resources are present
        let baselineResources = try storage.fetchResourcesForSessionId(testSessionId)
        XCTAssertFalse(baselineResources.isEmpty, "Baseline should have resources")

        // Simulate auto-recovery
        let recovered = try simulateAutoRecovery()
        defer { try? recovered.teardown() }

        // Fetch resources using stale session ID (this is what LogController.createResourcePayload does)
        let resources = try recovered.fetchResourcesForSessionId(testSessionId)
        XCTAssertTrue(resources.isEmpty,
                      "Resources should be empty for stale session after DB wipe")

        // Build ResourcePayload from empty resources (matches LogController code path)
        let resourcePayload = ResourcePayload(from: resources)
        XCTAssertNil(resourcePayload.appVersion,
                     "Log envelope resource app_version should be nil (defaultFilter skips)")
        XCTAssertNil(resourcePayload.osName,
                     "Log envelope resource os_name should be nil (Platform == PlatformUnknown)")

        // Build a LogRecord in-memory — the log DATA itself is fine
        let logRecord = LogRecord(
            identifier: LogIdentifier.random,
            processIdentifier: testProcessId,
            severity: .info,
            body: "User tapped checkout button",
            attributes: ["screen": .string("CartView")]
        )
        let logPayload = LogPayloadBuilder.build(log: logRecord)

        // The log body and attributes are intact — only the envelope resources are null
        XCTAssertEqual(logPayload.body, "User tapped checkout button",
                       "Log body should be intact regardless of DB state")
        XCTAssertFalse(logPayload.attributes.isEmpty,
                       "Log attributes should be intact regardless of DB state")
    }

    // MARK: - Test 6: Corrupted storage — addMetadata throws

    func test_corruptedStorage_addMetadataThrows() throws {
        // Add a session so we have a valid state
        try storage.addSession(
            id: testSessionId,
            state: .foreground,
            processId: testProcessId,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date()
        )

        // Corrupt the metadata table by dropping it
        try storage.dbQueue.write { db in
            try db.execute(sql: "DROP TABLE IF EXISTS metadata")
        }

        // Attempting to add metadata should now throw a DatabaseError
        // This matches the "Error setting JavaScript bundle path" symptom at EmbraceManager.swift:30
        XCTAssertThrowsError(
            try storage.addMetadata(
                key: AppResourceKey.appVersion.rawValue,
                value: "1.2.3",
                type: .requiredResource,
                lifespan: .process,
                lifespanId: testProcessId.hex
            ),
            "addMetadata should throw when metadata table is corrupted"
        ) { error in
            XCTAssertTrue(error is DatabaseError,
                          "Error should be a GRDB DatabaseError, got: \(type(of: error))")
        }
    }
}
