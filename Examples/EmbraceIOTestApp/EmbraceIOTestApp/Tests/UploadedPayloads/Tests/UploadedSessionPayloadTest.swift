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

    var sessionIdToTest: String = ""
    var personas: [String] = []
    var userInfo: UserInfo = .init()

    func test(networkSwizzle: NetworkingSwizzle) -> TestReport {
        var testItems = [TestReportItem]()

        let postedJsons = networkSwizzle.postedJsons[sessionIdToTest] ?? []
        if postedJsons.isEmpty {
            testItems.append(
                .init(target: "POST Jsons for session \(sessionIdToTest)", expected: "Found", recorded: "Missing"))
        }

        let exportedSpans = networkSwizzle.exportedSpansBySession[sessionIdToTest] ?? []
        if exportedSpans.isEmpty {
            testItems.append(
                .init(target: "Exported Spans for session \(sessionIdToTest)", expected: "Found", recorded: "Missing"))
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
            if !(userInfo.username ?? "").isEmpty {
                let username = metadataJson?["username"] as? String
                testItems.append(.init(target: "UserInfo Username", expected: userInfo.username, recorded: username))
            }
            if !(userInfo.email ?? "").isEmpty {
                let email = metadataJson?["email"] as? String
                testItems.append(.init(target: "UserInfo Email", expected: userInfo.email, recorded: email))
            }
            if !(userInfo.identifier ?? "").isEmpty {
                let user_id = metadataJson?["user_id"] as? String
                testItems.append(.init(target: "UserInfo Identifier", expected: userInfo.identifier, recorded: user_id))
            }
        }

        var foundSpans = 0
        var allowedMissing = 0
        exportedSpans.forEach { exportedSpan in
            postedJsons.forEach { postedJson in
                let data = postedJson["data"] as? JsonDictionary
                let postedSpans = data?["spans"] as? [JsonDictionary]
                let postedSpansSnapshots = data?["span_snapshots"] as? [JsonDictionary]
                let span = postedSpans?.first { $0["span_id"] as? String == exportedSpan.spanId.hexString }
                let spanSnap = postedSpansSnapshots?.first { $0["span_id"] as? String == exportedSpan.spanId.hexString }
                if span != nil || spanSnap != nil {
                    foundSpans += 1
                } else {
                    let result = missingSpanTestResult(exportedSpan.name)
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
        }
        testItems.append(
            .init(target: "Spans Count", expected: "\(exportedSpans.count - allowedMissing)", recorded: "\(foundSpans)")
        )
        let jsonType = (postedJsons.first { $0["type"] as? String != nil })?["type"] as? String
        testItems.append(.init(target: "type", expected: "spans", recorded: jsonType))

        let resources =
            postedJsons.first { $0["resource"] as? JsonDictionary != nil }?["resource"] as? JsonDictionary ?? [:]
        testResourceInclussion(on: resources, testItems: &testItems)
        return .init(items: testItems)
    }

    private func missingSpanTestResult(_ name: String) -> TestResult {
        switch name {
        case "emb-setup",
            "POST /api/v2/spans":
            return .warning
        default:
            return .fail
        }
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
