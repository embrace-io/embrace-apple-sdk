//
//  CrashesTests.swift
//  EmbraceIOTestApp
//
//

import EmbraceIO
import OpenTelemetryApi
import OpenTelemetrySdk
import SwiftUI

/// TODO: Crash Tests need more work so we're just removing "currentSessionId" usage for now so that the app compiles and runs.
/// Need to correlate the crash to the corresponding user session.
/// Need to also figure out how to add crash tests to the test suite since the debugger stops when a crash happens so it's not possible to test them as of now other than running a manual test.
///

class CrashesTests: PayloadTest {
    var testRelevantPayloadNames: [String] { [] }
    var requiresCleanup: Bool { false }
    var runImmediatelyIfLogsFound: Bool { crashTriggered }

    private var crashTriggered: Bool {
        UserDefaults.standard.bool(forKey: "CrashTriggered")
    }

    func runTestPreparations() {
        if !crashTriggered {
            recordCrash()

            // Gives time for User Defaults to store the crash record.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                var nullPointer: CrashTestDummyObject? = .init()

                nullPointer = nil

                nullPointer!.a = 2
            }
        }
    }

    func test(logs: [ReadableLogRecord]) -> TestReport {
        var testItems = [TestReportItem]()

        guard let crashLog = logs.first(where: { $0.attributes["emb.type"]?.description == "sys.ios.crash" }) else {
            testItems.append(.init(target: "emb.type", expected: "sys.ios.crash", recorded: "missing", result: .fail))
            return .init(items: testItems)
        }

        testItems.append(
            .init(target: "emb.type", expected: "sys.ios.crash", recorded: "sys.ios.crash", result: .success))
        testItems.append(evaluate("emb.provider", expecting: "kscrash", on: crashLog.attributes))
        testItems.append(contentsOf: OTelSemanticsValidation.validateAttributeNames(crashLog.attributes))
        clearCrashRecord()
        return .init(items: testItems)
    }

    private func recordCrash() {
        UserDefaults.standard.setValue(true, forKey: "CrashTriggered")
        UserDefaults.standard.synchronize()

    }

    private func clearCrashRecord() {
        UserDefaults.standard.setValue(false, forKey: "CrashTriggered")
        UserDefaults.standard.synchronize()
    }
}

class CrashTestDummyObject {
    var a: Int = 0
}
