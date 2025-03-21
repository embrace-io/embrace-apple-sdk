//
//  CrashesTests.swift
//  EmbraceIOTestApp
//
//

import OpenTelemetrySdk
import OpenTelemetryApi
import EmbraceIO
import SwiftUI

class CrashesTests: PayloadTest {
    var testRelevantPayloadNames: [String] { [] }
    var requiresCleanup: Bool { false }
    var runImmediatelyIfLogsFound: Bool { crashTriggered }

    private var crashTriggered: Bool {
        UserDefaults.standard.bool(forKey: "CrashTriggered")
    }

    private var crashedSessionId: String? {
        UserDefaults.standard.string(forKey: "CrashedSessionId")
    }

    func runTestPreparations() {
        if !crashTriggered {
            recordCrash()

            // Gives time for User Defaults to store the crash session.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                var nullPointer: CrashTestDummyObject? = .init()

                nullPointer = nil

                nullPointer!.a = 2
            }
        }
    }

    func test(logs: [ReadableLogRecord]) -> TestReport {
        var testItems = [TestReportItem]()

        guard let crashedSessionId = crashedSessionId else {
            testItems.append(.init(target: "crashedSessionId", expected: "cached crash session", recorded: "missing", result: .fail))
            return .init(items: testItems)
        }

        guard let crashLog = logs.first (where: { $0.attributes["emb.type"]?.description == "sys.ios.crash" }) else {
            testItems.append(.init(target: "emb.type", expected: "sys.ios.crash", recorded: "missing", result: .fail))
            return .init(items: testItems)
        }

        testItems.append(.init(target: "emb.type", expected: "sys.ios.crash", recorded: "sys.ios.crash", result: .success))
        testItems.append(evaluate("emb.payload", contains: crashedSessionId, on: crashLog.attributes))
        testItems.append(evaluate("emb.provider", expecting: "kscrash", on: crashLog.attributes))

        clearCrashRecord()
        return .init(items: testItems)
    }

    private func recordCrash() {
        UserDefaults.standard.setValue(true, forKey: "CrashTriggered")
        UserDefaults.standard.setValue(Embrace.client?.currentSessionId() ?? "INVALID", forKey: "CrashedSessionId")
        UserDefaults.standard.synchronize()

    }

    private func clearCrashRecord() {
        UserDefaults.standard.setValue(false, forKey: "CrashTriggered")
        UserDefaults.standard.setValue(nil, forKey: "CrashedSessionId")
        UserDefaults.standard.synchronize()
    }
}

class CrashTestDummyObject {
    var a: Int = 0
}
