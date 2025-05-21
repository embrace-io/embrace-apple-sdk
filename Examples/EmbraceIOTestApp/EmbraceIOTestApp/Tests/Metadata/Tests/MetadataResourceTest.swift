//
//  MetadataResourceTest.swift
//  EmbraceIOTestApp
//
//

import OpenTelemetrySdk
import OpenTelemetryApi

class MetadataResourceTest: PayloadTest {
    var testRelevantPayloadNames: [String] { ["emb-sdk-start"] }
    var requiresCleanup: Bool { false }
    var runImmediatelyIfSpansFound: Bool { true }
    var testType: TestType { .Spans }
    private var testRelevantSpanName: String {
        testRelevantPayloadNames[0]
    }

    private static var expectedKeys: [String] {
        ["emb.sdk.version",
         "emb.process_pre_warm",
         "emb.app.build_id",
         "emb.os.build_id",
         "emb.app.bundle_version",
         "emb.app.version",
         "service.name",
         "emb.app.environment_detailed",
         "os.type",
         "emb.process_identifier",
         "device.model.identifier",
         "os.version",
         "emb.device.architecture",
         "emb.device.is_jailbroken",
         "emb.device.timezone",
         "emb.os.variant",
         "emb.device.locale",
         "emb.process_start_time",
         "emb.app.framework",
         "emb.session.upload_index",
         "emb.app.environment",
         "emb.device.disk_size",
         "telemetry.sdk.language"]
    }

    private static func missingResourceMetadataKeys(on attributes: [String: AttributeValue]) -> [String] {
        return expectedKeys.filter { attributes[$0] == nil }
    }

    private static func unknownResourceMetadataKeys(on attributes: [String: AttributeValue]) -> [String] {
        return attributes.keys.filter { !expectedKeys.contains($0) }
    }

    func test(spans: [OpenTelemetrySdk.SpanData]) -> TestReport {
        var testItems = [TestReportItem]()

        guard let startSpan = spans.first, startSpan.name == testRelevantSpanName else {
            return .init(items: [.init(target: "\(testRelevantSpanName) span", expected: "exists", recorded: "missing", result: .fail)])
        }

        MetadataResourceTest.unknownResourceMetadataKeys(on: startSpan.resource.attributes).forEach{ unknownKey in
            testItems.append(.init(target: unknownKey, expected: "unexpected", recorded: "unexpected key found", result: .warning))
        }

        MetadataResourceTest.expectedKeys.forEach { key in
            testItems.append(evaluate(key, on: startSpan.resource.attributes))
        }

        return .init(items: testItems)
    }

    static func testMetadataInclussion(on resource: Resource, testItems: inout [TestReportItem]) {
        let missingMetadataKeys = missingResourceMetadataKeys(on: resource.attributes)
        testItems.append(.init(target: "Missing Metadata Keys", expected: "0 missing", recorded: "\(missingMetadataKeys.count) missing"))

        missingMetadataKeys.forEach { missingKey in
            testItems.append(.init(target: "Metadata Key \(missingKey)", expected: "exists", recorded: "missing"))
        }

        let unknownMetadataKeys = MetadataResourceTest.unknownResourceMetadataKeys(on: resource.attributes)
        if (unknownMetadataKeys.count > 0) {
            testItems.append(.init(target: "Unknown Metadata Keys", expected: "0", recorded: "\(missingMetadataKeys.count)", result: .warning))

            unknownMetadataKeys.forEach { unknownKey in
                testItems.append(.init(target: "Metadata Key \(unknownKey)", expected: "unexpected", recorded: "unexpected key found", result: .warning))
            }
        }
    }
}
