//
//  PerformanceLogTest.swift
//  EmbraceIOTestApp
//
//

import EmbraceIO
import OpenTelemetryApi
import OpenTelemetrySdk
import SwiftUI

class PerformanceLogTest: PayloadTest {
    var testRelevantPayloadNames: [String] { ["LoggingTestStart"] }
    var runImmediatelyIfSpansFound: Bool { true }
    var numberOfLoops: Int = 0
    var calculationsPerLoop: Int = 0
    var maxNumberOfLogs: Int = 0

    func runTestPreparations() {
        Embrace.client?.buildSpan(name: "LoggingTestStart").startSpan().end()
    }

    func test(spans: [SpanData]) -> TestReport {
        var testItems = [TestReportItem]()

        let nonLogsGroup = DispatchGroup()
        let logsGroup = DispatchGroup()
        let testGroup = DispatchGroup()

        let lock = NSLock()

        var nonLogsTotalTime: TimeInterval = 0
        var withLogsTotalTime: TimeInterval = 0
        testGroup.enter()

        for _ in 0..<numberOfLoops {
            lock.lock()
            nonLogsGroup.enter()
            lock.unlock()
            DispatchQueue.global().async { [weak self] in
                let start = Date()
                let numberOfCalculations = UInt32(self?.calculationsPerLoop ?? 0)
                for _ in 0..<numberOfCalculations {
                    var hasher = Hasher()
                    hasher.combine(UUID())
                    let _ = hasher.finalize()
                }
                lock.lock()
                nonLogsTotalTime += start.distance(to: Date())
                nonLogsGroup.leave()
                lock.unlock()
            }
        }

        nonLogsGroup.wait()

        for _ in 0..<numberOfLoops {
            lock.lock()
            logsGroup.enter()
            lock.unlock()
            DispatchQueue.global().async { [weak self] in
                let start = Date()
                var totalLogs = 0
                let numberOfCalculations = self?.calculationsPerLoop ?? 0
                let limitNumberOfLogsPerLoop = self?.maxNumberOfLogs ?? 0
                for _ in 0..<numberOfCalculations {
                    var hasher = Hasher()
                    hasher.combine(UUID())
                    let hash = hasher.finalize()
                    if totalLogs <= limitNumberOfLogsPerLoop {
                        Embrace.client?.log("hashed: \(hash)", severity: .info)
                        totalLogs += 1
                    }
                }
                lock.lock()
                withLogsTotalTime += start.distance(to: Date())
                logsGroup.leave()
                lock.unlock()
            }
        }
        logsGroup.wait()

        let nonSpansTime = String(format: "%.4f Seconds", nonLogsTotalTime / Double(numberOfLoops))
        let spansTime = String(format: "%.4f Seconds", withLogsTotalTime / Double(numberOfLoops))
        testItems.append(.init(target: "Control", expected: "", recorded: nonSpansTime, result: .unknown))
        testItems.append(.init(target: "Exporting Logs", expected: "", recorded: spansTime, result: .unknown))
        testGroup.leave()

        testGroup.wait()

        return .init(items: testItems)
    }
}
