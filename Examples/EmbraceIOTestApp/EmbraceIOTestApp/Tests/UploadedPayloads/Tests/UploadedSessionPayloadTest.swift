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

    func test(networkSwizzle: NetworkingSwizzle) -> TestReport {
        var testItems = [TestReportItem]()

        let postedJsons = networkSwizzle.postedJsons[sessionIdToTest] ?? []
        if postedJsons.isEmpty {
            testItems.append(.init(target: "POST Jsons for session \(sessionIdToTest)", expected: "Found", recorded: "Missing"))
        }

        let exportedSpans = networkSwizzle.exportedSpansBySession[sessionIdToTest] ?? []
        if exportedSpans.isEmpty {
            testItems.append(.init(target: "Exported Spans for session \(sessionIdToTest)", expected: "Found", recorded: "Missing"))
        }

        var foundSpans = 0
        var allowedMissing = 0
        exportedSpans.forEach { exportedSpan in
            postedJsons.forEach { postedJson in
                let data = postedJson["data"] as? JsonDictionary
                let postedSpans = data?["spans"] as? Array<JsonDictionary>
                let postedSpansSnapshots = data?["span_snapshots"] as? Array<JsonDictionary>
                let span = postedSpans?.first { $0["span_id"] as? String == exportedSpan.spanId.hexString }
                let spanSnap = postedSpansSnapshots?.first { $0["span_id"] as? String == exportedSpan.spanId.hexString }
                if span != nil || spanSnap != nil {
                    foundSpans += 1
                } else {
                    let result = missingSpanTestResult(exportedSpan.name)
                    if result == .warning {
                        allowedMissing += 1
                    }
                    testItems.append(.init(target: "\(exportedSpan.name): (\(exportedSpan.spanId.hexString))",
                                           expected: "Found",
                                           recorded: "Missing",
                                           result: result))
                }
            }
        }
        testItems.append(.init(target: "Spans Count", expected: "\(exportedSpans.count - allowedMissing)", recorded: "\(foundSpans)"))

        return .init(items: testItems)
    }

    private func missingSpanTestResult(_ name: String) -> TestResult {
        switch name {
        case "emb-setup":
            return .warning
        default:
            return .fail
        }
    }
}
