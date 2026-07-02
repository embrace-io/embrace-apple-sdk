//
//  UploadedSessionPayloadTest.swift
//  EmbraceIOTestApp
//
//

import Foundation

class UploadedSessionPayloadTest: PayloadTest {
    var expectedNotificationsForTestReady: [String] {
        ["NetworkingSwizzle.CapturedNewPayload"]
    }

    var partIdToTest: String = ""
    var personas: [String] = []
    var userInfo: UserInfo = .init()

    func test(networkSwizzle: NetworkingSwizzle) -> TestReport {
        var testItems = [TestReportItem]()

        let postedJsons = networkSwizzle.postedJsonsByPart[partIdToTest] ?? []
        if postedJsons.isEmpty {
            testItems.append(
                .init(target: "POST Jsons for part \(partIdToTest)", expected: "Found", recorded: "Missing"))
        }

        let exportedSpans = networkSwizzle.exportedSpansByPart[partIdToTest] ?? []
        if exportedSpans.isEmpty {
            testItems.append(
                .init(target: "Exported Spans for part \(partIdToTest)", expected: "Found", recorded: "Missing"))
        }

        postedJsons.forEach { postedJson in
            let metadataJson = postedJson["metadata"] as? JsonDictionary
            if let personasJsonArray = metadataJson?["personas"] as? [String] {
                let allPersonasFound = personas.allSatisfy { personasJsonArray.contains($0) }
                let missingPersonas = personas.filter { !personasJsonArray.contains($0) }
                let unexpectedPersonas = personasJsonArray.filter { !personas.contains($0) }
                let result: TestResult = allPersonasFound && unexpectedPersonas.count == 0 ? .success : .fail
                testItems.append(
                    .init(
                        target: "Personas",
                        expected: "\(personas.count)",
                        recorded: "\(personasJsonArray.count)",
                        result: result))
                missingPersonas.forEach {
                    testItems.append(.init(target: "Persona: \($0)", expected: "Found", recorded: "Missing"))
                }
                unexpectedPersonas.forEach {
                    testItems.append(.init(target: "Unexpected Persona: \($0)", expected: "Missing", recorded: "Found"))
                }
            } else {
                testItems.append(.init(target: "Personas Array", expected: "Found", recorded: "Missing"))
            }
            if !(userInfo.identifier ?? "").isEmpty {
                let user_id = metadataJson?["user_id"] as? String
                testItems.append(.init(target: "UserInfo Identifier", expected: userInfo.identifier, recorded: user_id))
            }
        }

        // Collect every span id present across all posted payloads for this session. A user session
        // is posted across multiple payloads (one per part in v7), so union them and match each
        // exported span exactly once — iterating per-payload would double-count and emit false misses.
        var postedSpanIds = Set<String>()
        postedJsons.forEach { postedJson in
            let data = postedJson["data"] as? JsonDictionary
            (data?["spans"] as? [JsonDictionary])?.forEach {
                if let id = $0["span_id"] as? String { postedSpanIds.insert(id) }
            }
            (data?["span_snapshots"] as? [JsonDictionary])?.forEach {
                if let id = $0["span_id"] as? String { postedSpanIds.insert(id) }
            }
        }

        // The SDK drops startup spans from the payload all-or-nothing (see `SpansPayloadBuilder`):
        // it keeps them only on a genuine cold launch where startup completes within its max length.
        // So if the payload kept ANY startup span, the rest are expected too (a missing one is a real
        // failure); if it kept none, they were all dropped and missing ones are expected.
        let startupSpansExpected = payloadContainsStartupSpan(in: postedJsons)

        var foundSpans = 0
        var allowedMissing = 0
        exportedSpans.forEach { exportedSpan in
            if postedSpanIds.contains(exportedSpan.spanId.hexString) {
                foundSpans += 1
            } else {
                let result = missingSpanTestResult(
                    name: exportedSpan.name,
                    embType: exportedSpan.attributes["emb.type"]?.description,
                    startupSpansExpected: startupSpansExpected)
                if result == .warning {
                    allowedMissing += 1
                }
                testItems.append(
                    .init(
                        target: "\(exportedSpan.name): (\(exportedSpan.spanId.hexString))",
                        expected: "Found",
                        recorded: "Missing",
                        result: result))
            }
        }
        testItems.append(
            .init(target: "Spans Count", expected: "\(exportedSpans.count - allowedMissing)", recorded: "\(foundSpans)")
        )
        let jsonType = (postedJsons.first { $0["type"] as? String != nil })?["type"] as? String
        testItems.append(.init(target: "type", expected: "spans", recorded: jsonType))

        testSessionIdentity(on: postedJsons, testItems: &testItems)

        let resources =
            postedJsons.first { $0["resource"] as? JsonDictionary != nil }?["resource"] as? JsonDictionary ?? [:]
        testResourceInclussion(on: resources, testItems: &testItems)
        return .init(items: testItems)
    }

    /// Validates the session-identity attributes stamped onto the `emb-session` span at payload-build
    /// time (they are NOT present on the exported span). In v7 `emb.session_part_id` carries the
    /// individual part UUID, `session.id` carries the user-session UUID, and `emb.user_session_id`
    /// mirrors `session.id`. `partIdToTest` is the part this payload was selected by.
    private func testSessionIdentity(on postedJsons: [JsonDictionary], testItems: inout [TestReportItem]) {
        let sessionSpanAttributesList = postedJsons.compactMap { sessionSpanAttributes(in: $0) }
        guard !sessionSpanAttributesList.isEmpty else {
            testItems.append(.init(target: "emb-session span in payload", expected: "Found", recorded: "Missing"))
            return
        }

        sessionSpanAttributesList.forEach { attributes in
            let partId = attributes["emb.session_part_id"]
            testItems.append(
                .init(
                    target: "emb.session_part_id",
                    expected: partIdToTest,
                    recorded: partId ?? "missing",
                    result: partId == partIdToTest ? .success : .fail))

            // `session.id` must be present (the user-session UUID) and distinct from the part id.
            let sessionId = attributes["session.id"] ?? ""
            let sessionIdValid = !sessionId.isEmpty && sessionId != partIdToTest
            testItems.append(
                .init(
                    target: "session.id",
                    expected: "non-empty user-session id (≠ part id)",
                    recorded: sessionId.isEmpty ? "missing" : sessionId,
                    result: sessionIdValid ? .success : .fail))

            // In v7 `emb.user_session_id` mirrors `session.id`.
            let userSessionId = attributes["emb.user_session_id"]
            testItems.append(
                .init(
                    target: "emb.user_session_id",
                    expected: sessionId,
                    recorded: userSessionId ?? "missing",
                    result: userSessionId == sessionId ? .success : .fail))

            testItems.append(.init(target: "emb.type", expected: "ux.session", recorded: attributes["emb.type"] ?? "missing"))
            testItems.append(
                .init(
                    target: "emb.user_session_part_index",
                    expected: "exists",
                    recorded: attributes["emb.user_session_part_index"] != nil ? "exists" : "missing",
                    result: attributes["emb.user_session_part_index"] != nil ? .success : .fail))

            // Unlike the live span (where the heartbeat attribute only appears after the first timer
            // tick), the payload always carries `emb.heartbeat_time_unix_nano`, derived from the
            // part's `lastHeartbeatTime` (initialized to its start time). Require a positive value.
            let heartbeat = attributes["emb.heartbeat_time_unix_nano"]
            let heartbeatValid = (heartbeat.flatMap { UInt64($0) } ?? 0) > 0
            testItems.append(
                .init(
                    target: "emb.heartbeat_time_unix_nano",
                    expected: "positive timestamp",
                    recorded: heartbeat ?? "missing",
                    result: heartbeatValid ? .success : .fail))
        }
    }

    /// Extracts the `emb-session` span's attributes (key → value) from a posted payload, checking
    /// both closed spans and span snapshots.
    private func sessionSpanAttributes(in postedJson: JsonDictionary) -> [String: String]? {
        let data = postedJson["data"] as? JsonDictionary
        let spans = (data?["spans"] as? [JsonDictionary]) ?? []
        let snapshots = (data?["span_snapshots"] as? [JsonDictionary]) ?? []
        guard
            let sessionSpan = (spans + snapshots).first(where: { $0["name"] as? String == "emb-session" }),
            let attributes = sessionSpan["attributes"] as? [[String: String]]
        else {
            return nil
        }
        return attributes.reduce(into: [String: String]()) { result, attribute in
            if let key = attribute["key"], let value = attribute["value"] {
                result[key] = value
            }
        }
    }

    private func missingSpanTestResult(name: String, embType: String?, startupSpansExpected: Bool) -> TestResult {
        // Startup spans (`emb.type == sys.startup`) are dropped from the uploaded payload by
        // `SpansPayloadBuilder` when the startup sequence exceeds its max length (~10s) or its root
        // span isn't available — the norm when the SDK is started manually, well after process
        // launch, as in this test app. On a genuine cold launch they are kept. `startupSpansExpected`
        // reflects the SDK's actual decision (did the payload keep any startup span?), so a missing
        // startup span only fails when startup spans were expected in this payload.
        if embType == "sys.startup" {
            return startupSpansExpected ? .fail : .warning
        }

        switch name {
        case "emb-setup",
            "emb-thread-blockage",
            "POST /api/v2/spans":
            return .warning
        default:
            return .fail
        }
    }

    /// Returns `true` if any span in the posted payloads is a startup span (`emb.type == sys.startup`).
    /// Because `SpansPayloadBuilder` keeps or drops startup spans all-or-nothing, the presence of one
    /// means startup spans were expected in this payload.
    private func payloadContainsStartupSpan(in postedJsons: [JsonDictionary]) -> Bool {
        for postedJson in postedJsons {
            let data = postedJson["data"] as? JsonDictionary
            let allSpans =
                ((data?["spans"] as? [JsonDictionary]) ?? []) + ((data?["span_snapshots"] as? [JsonDictionary]) ?? [])
            for span in allSpans {
                guard let attributes = span["attributes"] as? [[String: String]] else { continue }
                if attributes.contains(where: { $0["key"] == "emb.type" && $0["value"] == "sys.startup" }) {
                    return true
                }
            }
        }
        return false
    }

    private func testResourceInclussion(on resources: JsonDictionary, testItems: inout [TestReportItem]) {
        let missingResources = missingResource(on: resources)
        testItems.append(.init(target: "Missing Resources", expected: 0, recorded: missingResources.count))

        missingResources.forEach { missingKey in
            testItems.append(.init(target: "Resource \(missingKey)", expected: "exists", recorded: "missing"))
        }

        let nilValues = resourcesWithNilValues(resources)
        nilValues.forEach { nilValue in
            testItems.append(
                .init(
                    target: "Resource \(nilValue)", expected: "some value", recorded: "null",
                    result: nullValueResourceResult(for: nilValue)))
        }

        let unknownResourceKeys = unknownResourceKeys(on: resources)
        if unknownResourceKeys.count > 0 {
            testItems.append(
                .init(
                    target: "Unknown Resource Keys", expected: "0", recorded: "\(unknownResourceKeys.count)",
                    result: .warning))

            unknownResourceKeys.forEach { unknownKey in
                testItems.append(
                    .init(
                        target: "Resource Key \(unknownKey)", expected: "unexpected", recorded: "unexpected key found",
                        result: .warning))
            }
        }
    }

    private var expectedResourceKeys: [String] {
        [
            "app_bundle_id",
            "app_framework",
            "app_version",
            "build",
            "build_id",
            "device_architecture",
            "device_manufacturer",
            "device_model",
            "disk_total_capacity",
            "environment",
            "environment_detail",
            "jailbroken",
            "launch_count",
            "os_alternate_type",
            "os_build",
            "os_name",
            "os_type",
            "os_version",
            "process_identifier",
            "process_pre_warm",
            "process_start_time",
            "screen_resolution",
            "sdk_version"
        ]
    }

    private func missingResource(on resources: JsonDictionary) -> [String] {
        return expectedResourceKeys.filter { resources[$0] == nil }
    }

    private func unknownResourceKeys(on resources: JsonDictionary) -> [String] {
        return resources.keys.filter { !expectedResourceKeys.contains($0) }
    }

    private func resourcesWithNilValues(_ resources: JsonDictionary) -> [String] {
        return resources.filter({ $0.value is NSNull }).keys.map { $0 }
    }

    private func nullValueResourceResult(for key: String) -> TestResult {
        switch key {
        case "screen_resolution",
            "launch_count":
            return .warning
        default:
            return .fail
        }
    }
}
