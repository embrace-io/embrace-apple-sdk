//
//  PerformanceSpanTest.swift
//  EmbraceIOTestApp
//
//

import EmbraceIO
import OpenTelemetryApi
import OpenTelemetrySdk
import SwiftUI

class PerformanceSpanTest: PayloadTest {
    var testRelevantPayloadNames: [String] { ["HashingTestStart"] }
    var runImmediatelyIfSpansFound: Bool { true }
    var numberOfLoops: Int = 0
    var calculationsPerLoop: Int = 0
    var maxNumberOfSpans: Int = 0

    func runTestPreparations() {
        Embrace.client?.buildSpan(name: "HashingTestStart").startSpan().end()
    }

    func test(spans: [SpanData]) -> TestReport {
        var testItems = [TestReportItem]()

        let nonSpansGroup = DispatchGroup()
        let spansGroup = DispatchGroup()
        let testGroup = DispatchGroup()

        let lock = NSLock()

        var nonSpansTotalTime: TimeInterval = 0
        var withSpansTotalTime: TimeInterval = 0
        testGroup.enter()

        for _ in 0..<numberOfLoops {
            lock.lock()
            nonSpansGroup.enter()
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
                nonSpansTotalTime += start.distance(to: Date())
                nonSpansGroup.leave()
                lock.unlock()
            }
        }

        nonSpansGroup.wait()

        for _ in 0..<numberOfLoops {
            lock.lock()
            spansGroup.enter()
            lock.unlock()
            DispatchQueue.global().async { [weak self] in
                let start = Date()
                var totalSpans = 0
                let numberOfCalculations = self?.calculationsPerLoop ?? 0
                let limitNumberOfSpansPerLoop = self?.maxNumberOfSpans ?? 0
                for _ in 0..<numberOfCalculations {
                    var span: (any Span)?
                    lock.lock()
                    if totalSpans < limitNumberOfSpansPerLoop {
                        span = Embrace.client?.buildSpan(name: "HashingSpan").startSpan()
                        totalSpans += 1
                    }
                    lock.unlock()
                    var hasher = Hasher()
                    hasher.combine(UUID())
                    let hash = hasher.finalize()
                    span?.setAttribute(key: "hashed_number", value: hash)
                    span?.end()
                }
                lock.lock()
                withSpansTotalTime += start.distance(to: Date())
                spansGroup.leave()
                lock.unlock()
            }
        }
        spansGroup.wait()

        let nonSpansTime = String(format: "%.4f Seconds", nonSpansTotalTime / Double(numberOfLoops))
        let spansTime = String(format: "%.4f Seconds", withSpansTotalTime / Double(numberOfLoops))
        testItems.append(.init(target: "Control", expected: "", recorded: nonSpansTime, result: .unknown))
        testItems.append(.init(target: "Exporting Spans", expected: "", recorded: spansTime, result: .unknown))
        testGroup.leave()

        testGroup.wait()

        return .init(items: testItems)
    }
}
