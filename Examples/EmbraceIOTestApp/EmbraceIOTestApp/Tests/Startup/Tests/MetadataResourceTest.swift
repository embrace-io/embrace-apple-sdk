//
//  MetadataResourceTest.swift
//  EmbraceIOTestApp
//
//

import OpenTelemetryApi
import OpenTelemetrySdk

class MetadataResourceTest: PayloadTest {
    var testRelevantPayloadNames: [String] { ["emb-sdk-start-process"] }
    var requiresCleanup: Bool { false }
    var runImmediatelyIfSpansFound: Bool { true }
    var testType: TestType { .Spans }
    private var testRelevantSpanName: String {
        testRelevantPayloadNames[0]
    }

    private static var expectedKeys: [String] {
        [
            "device.model.identifier",
            "emb.app.build_id",
            "emb.app.environment",
            "emb.app.environment_detailed",
            "emb.app.framework",
            "emb.app.version",
            "emb.device.architecture",
            "emb.device.disk_size",
            "emb.device.is_jailbroken",
            "emb.device.locale",
            "emb.device.timezone",
            "emb.os.build_id",
            "emb.os.variant",
            "emb.process_identifier",
            "emb.process_pre_warm",
            "emb.process_start_time",
            "emb.sdk.version",
            "emb.session.upload_index",
            "emb.app.bundle_version",
            "service.name",
            "service.version",
            "telemetry.sdk.language",
            "os.type",
            "os.version",
        ]
    }

    private static func missingResourceMetadataKeys(on attributes: [String: AttributeValue]) -> [String] {
        return expectedKeys.filter { attributes[$0] == nil }
    }

    private static func unknownResourceMetadataKeys(on attributes: [String: AttributeValue]) -> [String] {
        return attributes.keys.filter { !expectedKeys.contains($0) }
    }
    private static var keysAllowedToBeMissing: [String] {
        ["emb.session.upload_index"]
    }
    private static func resultForMissingMetadataKey(_ key: String) -> TestResult {
        keysAllowedToBeMissing.contains(key) ? .warning : .fail
    }

    private static func allMissingKeysAreAllowed(_ missingKeys: [String]) -> Bool {
        missingKeys.allSatisfy { keysAllowedToBeMissing.contains($0) }
    }

    func test(spans: [OpenTelemetrySdk.SpanData]) -> TestReport {
        var testItems = [TestReportItem]()

        guard let startSpan = spans.first, startSpan.name == testRelevantSpanName else {
            return .init(items: [
                .init(target: "\(testRelevantSpanName) span", expected: "exists", recorded: "missing", result: .fail)
            ])
        }

        MetadataResourceTest.unknownResourceMetadataKeys(on: startSpan.resource.attributes).forEach { unknownKey in
            testItems.append(
                .init(target: unknownKey, expected: "unexpected", recorded: "unexpected key found", result: .warning))
        }

        MetadataResourceTest.expectedKeys.forEach { key in
            var item = evaluate(key, on: startSpan.resource.attributes)
            if item.result == .fail && MetadataResourceTest.keysAllowedToBeMissing.contains(key) {
                item = .init(target: item.target, expected: item.expected, recorded: item.recorded, result: .warning)
            }
            testItems.append(item)
        }

        return .init(items: testItems)
    }

    static func testMetadataInclussion(on resource: Resource, testItems: inout [TestReportItem]) {
        let missingMetadataKeys = missingResourceMetadataKeys(on: resource.attributes)
        let missingKeysResult: TestResult =
            missingMetadataKeys.count == 0 ? .success : allMissingKeysAreAllowed(missingMetadataKeys) ? .warning : .fail
        testItems.append(
            .init(
                target: "Missing Metadata Keys", expected: "0 missing",
                recorded: "\(missingMetadataKeys.count) missing", result: missingKeysResult))

        missingMetadataKeys.forEach { missingKey in
            testItems.append(
                .init(
                    target: "Metadata Key \(missingKey)", expected: "exists", recorded: "missing",
                    result: resultForMissingMetadataKey(missingKey)))
        }

        let unknownMetadataKeys = MetadataResourceTest.unknownResourceMetadataKeys(on: resource.attributes)
        if unknownMetadataKeys.count > 0 {
            testItems.append(
                .init(
                    target: "Unknown Metadata Keys", expected: "0", recorded: "\(unknownMetadataKeys.count)",
                    result: .warning))

            unknownMetadataKeys.forEach { unknownKey in
                testItems.append(
                    .init(
                        target: "Metadata Key \(unknownKey)", expected: "unexpected", recorded: "unexpected key found",
                        result: .warning))
            }
        }
    }
}
