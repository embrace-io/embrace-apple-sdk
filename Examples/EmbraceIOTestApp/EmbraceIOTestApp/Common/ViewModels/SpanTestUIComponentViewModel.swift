//
//  SpanTestUIComponentViewModel.swift
//  EmbraceIOTestApp
//
//

import SwiftUI
import OpenTelemetrySdk

class SpanTestUIComponentViewModel: UIComponentViewModelBase {
    var spanExporter: TestSpanExporter = .init()
    private weak var observingObject: NSObjectProtocol?

    override func testButtonPressed() {
        super.testButtonPressed()
        
        // if test object requirest tests to be run immediately if relevant spans are already present
        guard !payloadTestObject.runImmediatelyIfSpansFound || !allRevelantSpansAreAlreadyCached else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.performTest()
            }
            return
        }

        if payloadTestObject.requiresCleanup {
            spanExporter.clearAll(payloadTestObject.testRelevantPayloadNames)
        }

        registerForNotification()

        payloadTestObject.runTestPreparations()
    }

    private var allRevelantSpansAreAlreadyCached: Bool {
        payloadTestObject.testRelevantPayloadNames.allSatisfy { spanName in
            (spanExporter.cachedExportedSpans[spanName] ?? []).count > 0
        }
    }

    private var relevantSpans: [SpanData] {
        var spans = [SpanData]()
        payloadTestObject.testRelevantPayloadNames.forEach { spanName in
            guard let span = spanExporter.cachedExportedSpans[spanName] else { return }
            spans.append(contentsOf: span)
        }
        return spans
    }

    private func registerForNotification() {
        observingObject = NotificationCenter.default.addObserver(forName: .init("TestSpanExporter.SpansUpdated"), object: nil, queue: nil) { [weak self] _ in
            self?.performTest()
        }
    }

    private func performTest() {
        let spans = relevantSpans
        guard
            !spans.isEmpty
        else { return }

        let testReport = payloadTestObject.test(spans: spans)
        testFinished(with: testReport)
        unregisterNotification()
    }

    private func unregisterNotification() {
        guard let observingObject = observingObject else { return }

        NotificationCenter.default.removeObserver(observingObject, name: .init("TestSpanExporter.SpansUpdated"), object: nil)
    }
}
